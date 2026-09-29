import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';
import * as path from 'path';
import * as fs from 'fs';
import { PrismaService } from '../prisma/prisma.service';

export interface SendWelcomeEmailOptions {
  userId: string;
  email: string;
  fullName?: string | null;
  googleFullName?: string | null;
}

@Injectable()
export class MailService implements OnModuleInit {
  private readonly logger = new Logger(MailService.name);
  private transporter: nodemailer.Transporter | null = null;
  private readonly inFlightEmails = new Set<string>();

  constructor(
    private readonly configService: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  async onModuleInit() {
    this.initTransporter();
  }

  private initTransporter() {
    const host = this.configService.get<string>('SMTP_HOST', 'smtp.gmail.com');
    const port = Number(this.configService.get<number>('SMTP_PORT', 465));
    const secureConfig = this.configService.get<string>('SMTP_SECURE', 'true');
    const secure = secureConfig === 'true' || port === 465;
    const user = this.configService.get<string>('SMTP_USER');
    let pass = this.configService.get<string>('SMTP_APP_PASSWORD');

    if (!user || !pass) {
      this.logger.warn('SMTP configuration is missing. Welcome emails will be disabled.');
      return;
    }

    // Gmail App Passwords may contain spaces (e.g. "xxxx xxxx xxxx xxxx"); strip them for SMTP auth
    pass = pass.replace(/\s+/g, '');

    try {
      this.transporter = nodemailer.createTransport({
        host,
        port,
        secure,
        connectionTimeout: 8000,
        greetingTimeout: 8000,
        socketTimeout: 10000,
        auth: {
          user,
          pass,
        },
      });

      this.logger.log(`SMTP service initialized with host: ${host}:${port} (SSL: ${secure})`);
    } catch (err) {
      this.logger.error('Failed to initialize SMTP transporter');
    }
  }

  /**
   * Verify SMTP connection status without exposing any credentials.
   */
  async verifyConnection(): Promise<{ success: boolean; message: string }> {
    const webhookUrl = this.configService.get<string>('GMAIL_WEBHOOK_URL');
    if (webhookUrl) {
      return { success: true, message: 'Google Apps Script HTTPS Webhook configured' };
    }

    const brevoKey = this.configService.get<string>('BREVO_API_KEY');
    if (brevoKey) {
      return { success: true, message: 'Brevo HTTPS API configured' };
    }

    const resendKey = this.configService.get<string>('RESEND_API_KEY');
    if (resendKey) {
      return { success: true, message: 'Resend HTTPS API configured' };
    }

    if (!this.transporter) {
      return { success: false, message: 'SMTP transporter not initialized' };
    }

    try {
      await this.transporter.verify();
      this.logger.log('SMTP connection verification succeeded');
      return { success: true, message: 'SMTP connection verified successfully' };
    } catch (err: any) {
      const safeErrorMsg = err?.message || 'Connection failed';
      this.logger.error(`SMTP connection verification failed: ${safeErrorMsg}`);
      return { success: false, message: safeErrorMsg };
    }
  }

  /**
   * Resolve user display name with fallback hierarchy:
   * 1. Google account display name
   * 2. Existing user display name
   * 3. Email-derived name
   * 4. "there" as fallback
   */
  resolveDisplayName(options: {
    fullName?: string | null;
    googleFullName?: string | null;
    email: string;
  }): string {
    if (options.googleFullName && options.googleFullName.trim().length > 0) {
      return options.googleFullName.trim();
    }
    if (options.fullName && options.fullName.trim().length > 0) {
      return options.fullName.trim();
    }
    if (options.email && options.email.includes('@')) {
      const localPart = options.email.split('@')[0];
      const cleaned = localPart.replace(/[._-]+/g, ' ').trim();
      if (cleaned.length > 0) {
        // Capitalize each word
        return cleaned
          .split(' ')
          .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
          .join(' ');
      }
    }
    return 'there';
  }

  /**
   * Resolves the official DHA Vault brand logo image as an inline CID MIME attachment.
   * This guarantees that email clients (Gmail, Apple Mail, Outlook) render the logo
   * crisply without stripping inline SVGs or relying on external image hosts.
   */
  private getLogoAttachment(): { filename: string; content: Buffer; cid: string; contentType: string } | null {
    const candidatePaths = [
      path.join(process.cwd(), 'assets', 'dha_vault_logo_email.png'),
      path.join(process.cwd(), 'assets', 'dha_vault_logo.png'),
      path.join(__dirname, '../../assets', 'dha_vault_logo_email.png'),
      path.join(__dirname, '../../assets', 'dha_vault_logo.png'),
      path.join(__dirname, '../assets', 'dha_vault_logo_email.png'),
      path.join(__dirname, '../assets', 'dha_vault_logo.png'),
      path.join(process.cwd(), '../mobile/assets/branding/dha_vault_logo.png'),
    ];

    for (const p of candidatePaths) {
      if (fs.existsSync(p)) {
        try {
          const buffer = fs.readFileSync(p);
          if (buffer && buffer.length > 0) {
            return {
              filename: 'dha_vault_logo.png',
              content: buffer,
              cid: 'dha_vault_logo',
              contentType: 'image/png',
            };
          }
        } catch {
          // continue checking candidates
        }
      }
    }
    return null;
  }

  /**
   * Sends a professional DHA Vault welcome email to a genuinely new user.
   * Guarantees duplicate-send protection via database records and in-flight mutex.
   * Failures are safely handled without disrupting registration/authentication.
   */
  async sendWelcomeEmail(options: SendWelcomeEmailOptions): Promise<{ success: boolean; skipped?: boolean; error?: string }> {
    const { userId, email } = options;

    if (!email || !userId) {
      return { success: false, error: 'Missing userId or email' };
    }

    // 1. In-flight concurrency lock to prevent simultaneous duplicate requests
    if (this.inFlightEmails.has(userId)) {
      this.logger.log(`Welcome email for user ${userId} is already in progress. Skipping duplicate.`);
      return { success: true, skipped: true };
    }

    this.inFlightEmails.add(userId);

    try {
      // 2. Persistent duplicate check in database (zero migration, uses Notification model)
      const existingNotification = await this.prisma.notification.findFirst({
        where: {
          userId,
          type: 'WELCOME_EMAIL',
        },
      });

      if (existingNotification) {
        this.logger.log(`Welcome email already sent to user ${userId} at ${existingNotification.createdAt}. Skipping duplicate.`);
        return { success: true, skipped: true };
      }

      const webhookUrl = this.configService.get<string>('GMAIL_WEBHOOK_URL');
      const brevoKey = this.configService.get<string>('BREVO_API_KEY');
      const resendKey = this.configService.get<string>('RESEND_API_KEY');

      if (!webhookUrl && !brevoKey && !resendKey && !this.transporter) {
        this.initTransporter();
      }

      if (!webhookUrl && !brevoKey && !resendKey && !this.transporter) {
        this.logger.warn('No email transport configured (neither HTTPS webhook, Brevo, Resend, nor SMTP). Cannot deliver welcome email.');
        return { success: false, error: 'No email transport configured' };
      }

      this.logger.log(`Dispatching welcome email to ${email} (userId: ${userId})`);

      const name = this.resolveDisplayName({
        fullName: options.fullName,
        googleFullName: options.googleFullName,
        email,
      });

      const fromName = this.configService.get<string>('SMTP_FROM_NAME', 'DHA Vault');
      const fromEmail = this.configService.get<string>('SMTP_FROM_EMAIL', this.configService.get<string>('SMTP_USER', 'ro224313@gmail.com'));
      const subject = 'Welcome to DHA Vault — Your Secure Digital Locker';

      const textBody = this.buildPlainTextWelcomeEmail(name);
      const htmlBody = this.buildHtmlWelcomeEmail(name);

      let messageId = 'unknown';

      if (webhookUrl) {
        this.logger.log(`Dispatching welcome email via Google Apps Script HTTPS Webhook to ${email}`);
        const res = await fetch(webhookUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            to: email,
            subject,
            html: htmlBody,
            text: textBody,
            fromName,
          }),
          redirect: 'follow',
        });
        if (!res.ok) {
          throw new Error(`Google Apps Script Webhook returned HTTP status ${res.status}`);
        }
        messageId = `webhook-${Date.now()}`;
      } else if (brevoKey) {
        this.logger.log(`Dispatching welcome email via Brevo HTTPS API to ${email}`);
        const res = await fetch('https://api.brevo.com/v3/smtp/email', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'api-key': brevoKey,
          },
          body: JSON.stringify({
            sender: { name: fromName, email: fromEmail },
            to: [{ email, name }],
            subject,
            htmlContent: htmlBody,
            textContent: textBody,
          }),
        });
        if (!res.ok) {
          const errText = await res.text();
          throw new Error(`Brevo API returned HTTP status ${res.status}: ${errText}`);
        }
        const data = (await res.json()) as any;
        messageId = data?.messageId || `brevo-${Date.now()}`;
      } else if (resendKey) {
        this.logger.log(`Dispatching welcome email via Resend HTTPS API to ${email}`);
        const configuredResendFrom = this.configService.get<string>('RESEND_FROM_EMAIL');
        const resendFrom = configuredResendFrom
          ? (configuredResendFrom.includes('<') ? configuredResendFrom : `"${fromName}" <${configuredResendFrom}>`)
          : 'DHA Vault <onboarding@resend.dev>';

        let res = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${resendKey}`,
          },
          body: JSON.stringify({
            from: resendFrom,
            to: email,
            subject,
            html: htmlBody,
            text: textBody,
          }),
        });

        // If Resend restricts to account owner in sandbox mode (unverified domain):
        if (!res.ok && res.status === 403) {
          const errText = await res.text();
          if (errText.includes('only send testing emails to your own email address')) {
            const ownerEmail = this.configService.get<string>('SMTP_USER', 'ro224313@gmail.com');
            this.logger.warn(`Resend sandbox restriction: domain unverified. Routing preview welcome email to verified owner: ${ownerEmail} for user ${email}`);

            res = await fetch('https://api.resend.com/emails', {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                Authorization: `Bearer ${resendKey}`,
              },
              body: JSON.stringify({
                from: resendFrom,
                to: ownerEmail,
                subject: `${subject} [Preview for ${email}]`,
                html: `<div style="background:#1e293b;color:#f8fafc;padding:14px;border-left:4px solid #3b82f6;border-radius:6px;margin-bottom:20px;font-family:sans-serif;font-size:14px;"><strong>ℹ️ Resend Sandbox Notice:</strong> This welcome email was generated for <strong>${email}</strong> and delivered to your registered Resend account (<strong>${ownerEmail}</strong>) because a custom domain is not yet verified.</div>` + htmlBody,
                text: `[Resend Sandbox preview for ${email}]\n\n` + textBody,
              }),
            });
          } else {
            throw new Error(`Resend API returned HTTP status 403: ${errText}`);
          }
        }

        if (!res.ok) {
          const errText = await res.text();
          throw new Error(`Resend API returned HTTP status ${res.status}: ${errText}`);
        }
        const data = (await res.json()) as any;
        messageId = data?.id || `resend-${Date.now()}`;
      } else if (this.transporter) {
        const logoAttachment = this.getLogoAttachment();
        const attachments: any[] = [];
        if (logoAttachment) {
          attachments.push(logoAttachment);
        }

        const info = await this.transporter.sendMail({
          from: `"${fromName}" <${fromEmail}>`,
          to: email,
          replyTo: fromEmail,
          subject,
          text: textBody,
          html: htmlBody,
          attachments,
        });
        messageId = info?.messageId || 'unknown';
      }

      this.logger.log(`Welcome email successfully sent to ${email} (MessageId: ${messageId})`);

      // 3. Record welcome email in database for persistent duplicate protection
      await this.prisma.notification.create({
        data: {
          userId,
          title: 'Welcome to DHA Vault',
          message: 'Welcome to DHA Vault! Your secure digital document locker is ready.',
          type: 'WELCOME_EMAIL',
          isRead: false,
          metadata: {
            sentTo: email,
            sentAt: new Date().toISOString(),
            messageId: messageId || null,
          },
        },
      });

      return { success: true };
    } catch (err: any) {
      // Safe server-side error logging: NEVER log passwords or secrets
      const safeErrorMessage = err?.message || 'Unknown SMTP error';
      this.logger.error(`Welcome email delivery failed for new user: ${safeErrorMessage}`);
      return { success: false, error: safeErrorMessage };
    } finally {
      this.inFlightEmails.delete(userId);
    }
  }

  /**
   * Generates the plain-text fallback welcome email.
   */
  private buildPlainTextWelcomeEmail(name: string): string {
    return `Hello ${name},

Welcome to DHA Vault.

Your account has been successfully created, and your secure digital locker is ready.

With DHA Vault, you can securely organize and access your important documents from one place.

You can use DHA Vault to:

• Store important documents
• Scan documents
• Upload PDFs and images
• Quickly view your documents
• Search your document vault
• Share documents directly from your device
• Manage your personal digital records securely

Your privacy and security are important to us.

Thank you for choosing DHA Vault.

Regards,
DHA Vault
Your Documents. Secured. Organized. Instantly Accessible.
`;
  }

  /**
   * Generates a professional, responsive HTML email with DHA Vault dark-navy branding.
   */
  private buildHtmlWelcomeEmail(name: string): string {
    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Welcome to DHA Vault</title>
  <style>
    body {
      margin: 0;
      padding: 0;
      background-color: #0B0F19;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      color: #E2E8F0;
      -webkit-font-smoothing: antialiased;
    }
    .email-wrapper {
      width: 100%;
      background-color: #0B0F19;
      padding: 30px 15px;
      box-sizing: border-box;
    }
    .email-container {
      max-width: 580px;
      margin: 0 auto;
      background-color: #111827;
      border: 1px solid #1E293B;
      border-radius: 16px;
      overflow: hidden;
      box-shadow: 0 10px 25px rgba(0, 0, 0, 0.4);
    }
    .header {
      background: linear-gradient(135deg, #0F172A 0%, #1E1B4B 100%);
      padding: 36px 30px;
      text-align: center;
      border-bottom: 1px solid #1E293B;
    }
    .logo-img {
      display: inline-block;
      width: 72px;
      height: 72px;
      border-radius: 16px;
      margin-bottom: 14px;
      box-shadow: 0 6px 18px rgba(0, 0, 0, 0.4);
    }
    .brand-name {
      font-size: 22px;
      font-weight: 800;
      color: #FFFFFF;
      letter-spacing: 0.5px;
      margin: 0;
    }
    .brand-tagline {
      font-size: 12px;
      color: #06B6D4;
      font-weight: 600;
      letter-spacing: 1px;
      margin-top: 4px;
      text-transform: uppercase;
    }
    .content {
      padding: 36px 32px;
      line-height: 1.6;
    }
    .greeting {
      font-size: 20px;
      font-weight: 700;
      color: #F8FAFC;
      margin: 0 0 16px 0;
    }
    .paragraph {
      font-size: 15px;
      color: #94A3B8;
      margin: 0 0 16px 0;
      line-height: 1.6;
    }
    .feature-card {
      background-color: #1E293B;
      border: 1px solid #334155;
      border-radius: 12px;
      padding: 20px 24px;
      margin: 24px 0;
    }
    .feature-title {
      font-size: 14px;
      font-weight: 700;
      color: #38BDF8;
      margin: 0 0 12px 0;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .feature-list {
      list-style-type: none;
      padding: 0;
      margin: 0;
    }
    .feature-item {
      font-size: 14px;
      color: #E2E8F0;
      padding: 6px 0;
      display: flex;
      align-items: center;
    }
    .feature-bullet {
      color: #38BDF8;
      font-size: 16px;
      margin-right: 10px;
      line-height: 1;
    }
    .security-note {
      background: rgba(6, 182, 212, 0.08);
      border-left: 3px solid #06B6D4;
      padding: 12px 16px;
      border-radius: 0 8px 8px 0;
      margin: 24px 0;
      font-size: 13px;
      color: #CBD5E1;
    }
    .sign-off {
      margin-top: 28px;
      font-size: 14px;
      color: #94A3B8;
    }
    .sign-off strong {
      color: #FFFFFF;
      font-size: 15px;
    }
    .tagline-sub {
      display: block;
      color: #64748B;
      font-size: 12px;
      margin-top: 4px;
      font-style: italic;
    }
    .footer {
      background-color: #090D16;
      padding: 24px 30px;
      text-align: center;
      border-top: 1px solid #1E293B;
    }
    .footer-text {
      font-size: 12px;
      color: #64748B;
      margin: 0;
      line-height: 1.5;
    }
  </style>
</head>
<body>
  <div class="email-wrapper">
    <div class="email-container">
      <!-- Header -->
      <div class="header">
        <div style="text-align: center; margin-bottom: 16px;">
          <img src="cid:dha_vault_logo" class="logo-img" width="72" height="72" alt="DHA Vault" style="display: inline-block; width: 72px; height: 72px; border-radius: 16px; border: 0; outline: none; text-decoration: none; vertical-align: middle; box-shadow: 0 6px 18px rgba(0, 0, 0, 0.4);" />
        </div>
        <h1 class="brand-name">DHA Vault</h1>
        <div class="brand-tagline">Secure Digital Locker</div>
      </div>

      <!-- Main Content -->
      <div class="content">
        <h2 class="greeting">Hello ${name},</h2>
        
        <p class="paragraph">
          Welcome to <strong>DHA Vault</strong>.
        </p>

        <p class="paragraph">
          Your account has been successfully created, and your secure digital locker is ready.
        </p>

        <p class="paragraph">
          With DHA Vault, you can securely organize and access your important documents from one place.
        </p>

        <!-- Features Box -->
        <div class="feature-card">
          <div class="feature-title">You can use DHA Vault to:</div>
          <ul class="feature-list">
            <li class="feature-item"><span class="feature-bullet">•</span> Store important documents</li>
            <li class="feature-item"><span class="feature-bullet">•</span> Scan documents</li>
            <li class="feature-item"><span class="feature-bullet">•</span> Upload PDFs and images</li>
            <li class="feature-item"><span class="feature-bullet">•</span> Quickly view your documents</li>
            <li class="feature-item"><span class="feature-bullet">•</span> Search your document vault</li>
            <li class="feature-item"><span class="feature-bullet">•</span> Share documents directly from your device</li>
            <li class="feature-item"><span class="feature-bullet">•</span> Manage your personal digital records securely</li>
          </ul>
        </div>

        <div class="security-note">
          🔒 <strong>Your privacy and security are important to us.</strong> All your documents in DHA Vault are protected with authenticated access and client-side privacy controls.
        </div>

        <p class="paragraph">
          Thank you for choosing DHA Vault.
        </p>

        <div class="sign-off">
          Regards,<br>
          <strong>DHA Vault</strong>
          <span class="tagline-sub">Your Documents. Secured. Organized. Instantly Accessible.</span>
        </div>
      </div>

      <!-- Footer -->
      <div class="footer">
        <p class="footer-text">
          This is an automated notification confirming your DHA Vault account registration.<br>
          © ${new Date().getFullYear()} DHA Vault. All rights reserved.
        </p>
      </div>
    </div>
  </div>
</body>
</html>`;
  }
}
