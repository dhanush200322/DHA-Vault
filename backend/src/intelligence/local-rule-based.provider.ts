import { Injectable, Logger } from '@nestjs/common';
import {
  ClassificationResult,
  DocumentAiProvider,
} from './document-ai-provider.interface';

@Injectable()
export class LocalRuleBasedProvider implements DocumentAiProvider {
  readonly name = 'local-rule-based';
  private readonly logger = new Logger(LocalRuleBasedProvider.name);

  // Document Type Keywords
  private readonly keywordRules: Record<
    string,
    { keywords: string[]; category: string; tags: string[]; weight: number }
  > = {
    AADHAAR: {
      keywords: [
        'aadhaar',
        'uidai',
        'unique identification authority',
        'mera aadhaar',
        'enrolment no',
        'government of india',
      ],
      category: 'Identity',
      tags: ['#identity', '#government', '#aadhaar'],
      weight: 1.0,
    },
    PAN: {
      keywords: [
        'income tax department',
        'permanent account number',
        'pan card',
        'govt of india',
        'father name',
      ],
      category: 'Identity',
      tags: ['#identity', '#finance', '#tax', '#pan'],
      weight: 1.0,
    },
    PASSPORT: {
      keywords: [
        'passport',
        'republic of india',
        'nationality indian',
        'given name',
        'surname',
        'type p',
        'place of issue',
      ],
      category: 'Identity',
      tags: ['#identity', '#travel', '#passport', '#government'],
      weight: 1.0,
    },
    DRIVING_LICENCE: {
      keywords: [
        'driving licence',
        'driving license',
        'union of india',
        'motor vehicles',
        'transport department',
        'dl no',
        'licence no',
        'license no',
        'authorisation to drive',
        'validity non-transport',
      ],
      category: 'Vehicle',
      tags: ['#identity', '#vehicle', '#driving_licence', '#transport'],
      weight: 1.0,
    },
    INSURANCE: {
      keywords: [
        'insurance',
        'policy number',
        'policy no',
        'sum insured',
        'premium amount',
        'period of insurance',
        'insured name',
        'coverage',
      ],
      category: 'Insurance',
      tags: ['#insurance', '#finance', '#policy'],
      weight: 0.9,
    },
    VEHICLE: {
      keywords: [
        'registration certificate',
        'rc book',
        'chassis no',
        'engine no',
        'vehicle class',
        'maker model',
        'fuel type',
        'bharat stage',
      ],
      category: 'Vehicle',
      tags: ['#vehicle', '#transport', '#rc'],
      weight: 0.9,
    },
    EDUCATION_CERTIFICATE: {
      keywords: [
        'degree certificate',
        'convocation',
        'conferred the degree',
        'university',
        'institute of technology',
        'bachelor of',
        'master of',
        'academic year',
      ],
      category: 'Education',
      tags: ['#education', '#certificate', '#degree'],
      weight: 0.9,
    },
    MARKSHEET: {
      keywords: [
        'statement of marks',
        'mark sheet',
        'grade card',
        'semester',
        'cgpa',
        'credits',
        'board of secondary education',
        'cbse',
      ],
      category: 'Education',
      tags: ['#education', '#marksheet', '#grades'],
      weight: 0.9,
    },
    EMPLOYMENT: {
      keywords: [
        'offer letter',
        'employment contract',
        'appointment letter',
        'salary slip',
        'payslip',
        'employee code',
        'ctc',
        'designation',
      ],
      category: 'Finance',
      tags: ['#employment', '#career', '#finance'],
      weight: 0.8,
    },
    BANK: {
      keywords: [
        'account statement',
        'bank statement',
        'account number',
        'ifsc',
        'bank branch',
        'debit',
        'credit',
        'balance',
        'cheque',
      ],
      category: 'Finance',
      tags: ['#finance', '#bank', '#statement'],
      weight: 0.9,
    },
    MEDICAL: {
      keywords: [
        'prescription',
        'hospital',
        'diagnostic report',
        'dr.',
        'doctor',
        'patient',
        'clinic',
        'lab report',
        'medication',
      ],
      category: 'Medical',
      tags: ['#medical', '#health', '#records'],
      weight: 0.9,
    },
    PROPERTY: {
      keywords: [
        'sale deed',
        'lease agreement',
        'rental agreement',
        'property tax',
        'registry',
        'khata',
        'patta',
        'possession',
      ],
      category: 'Property',
      tags: ['#property', '#real_estate', '#agreement'],
      weight: 0.8,
    },
    RECEIPT: {
      keywords: [
        'tax invoice',
        'receipt',
        'payment receipt',
        'gstin',
        'billed to',
        'invoice number',
        'total amount',
      ],
      category: 'Finance',
      tags: ['#receipt', '#invoice', '#finance'],
      weight: 0.8,
    },
    CONTRACT: {
      keywords: [
        'non-disclosure agreement',
        'agreement between',
        'memorandum of understanding',
        'witnesseth',
        'terms and conditions',
      ],
      category: 'General',
      tags: ['#legal', '#contract', '#agreement'],
      weight: 0.8,
    },
  };

  async classifyDocument(text: string, fileName?: string): Promise<ClassificationResult> {
    const normalizedText = (text || '').toLowerCase();
    const normalizedFile = (fileName || '').toLowerCase();

    let bestType = 'OTHER';
    let highestScore = 0;
    let matchedCategory = 'General';
    let matchedTags: string[] = ['#document'];

    // Layer 1: Filename heuristics (boost score)
    const fileScores: Record<string, number> = {};
    if (normalizedFile) {
      if (normalizedFile.includes('aadhaar') || normalizedFile.includes('aadhar') || normalizedFile.includes('uidai')) {
        fileScores['AADHAAR'] = 0.45;
      }
      if (normalizedFile.includes('pan') || normalizedFile.includes('pancard')) {
        fileScores['PAN'] = 0.45;
      }
      if (normalizedFile.includes('passport')) {
        fileScores['PASSPORT'] = 0.45;
      }
      if (
        normalizedFile.includes('licence') ||
        normalizedFile.includes('license') ||
        normalizedFile.includes('driving') ||
        normalizedFile.includes('dl')
      ) {
        fileScores['DRIVING_LICENCE'] = 0.45;
      }
      if (normalizedFile.includes('insurance') || normalizedFile.includes('policy')) {
        fileScores['INSURANCE'] = 0.40;
      }
      if (normalizedFile.includes('vehicle') || normalizedFile.includes('rc')) {
        fileScores['VEHICLE'] = 0.40;
      }
      if (normalizedFile.includes('marksheet') || normalizedFile.includes('grade')) {
        fileScores['MARKSHEET'] = 0.40;
      }
      if (normalizedFile.includes('certificate') || normalizedFile.includes('degree')) {
        fileScores['EDUCATION_CERTIFICATE'] = 0.40;
      }
      if (normalizedFile.includes('medical') || normalizedFile.includes('prescription')) {
        fileScores['MEDICAL'] = 0.40;
      }
    }

    // Layer 2: Keyword matching
    for (const [docType, rule] of Object.entries(this.keywordRules)) {
      let matchedCount = 0;
      for (const kw of rule.keywords) {
        if (normalizedText.includes(kw)) {
          matchedCount++;
        }
      }

      let score = (fileScores[docType] || 0);
      if (matchedCount > 0) {
        // Base confidence calculated from keyword density
        const keywordRatio = Math.min(matchedCount / 3, 1.0);
        score += keywordRatio * 0.55 * rule.weight;
      }

      if (score > highestScore) {
        highestScore = score;
        bestType = docType;
        matchedCategory = rule.category;
        matchedTags = rule.tags;
      }
    }

    // Layer 3: Pattern confirmation boost
    if (bestType === 'PAN' && /[A-Z]{5}[0-9]{4}[A-Z]/.test(text.toUpperCase())) {
      highestScore = Math.min(highestScore + 0.35, 0.98);
    } else if (bestType === 'AADHAAR' && /\b\d{4}\s\d{4}\s\d{4}\b/.test(text)) {
      highestScore = Math.min(highestScore + 0.35, 0.98);
    } else if (bestType === 'PASSPORT' && /\b[A-Z][0-9]{7}\b/.test(text.toUpperCase())) {
      highestScore = Math.min(highestScore + 0.35, 0.96);
    }

    // Fallback if no strong match
    if (highestScore < 0.35) {
      bestType = 'OTHER';
      highestScore = 0.40;
      matchedCategory = 'General';
      matchedTags = ['#document', '#vault'];
    }

    const confidence = Math.min(Math.max(Number(highestScore.toFixed(2)), 0.3), 0.99);

    const summary = await this.summarizeDocument(bestType, {});

    return {
      documentType: bestType,
      confidence,
      suggestedCategory: matchedCategory,
      suggestedTags: matchedTags,
      summary,
    };
  }

  async extractFields(documentType: string, text: string): Promise<Record<string, any>> {
    const fields: Record<string, any> = {};
    if (!text) return fields;

    // Helper: Find date patterns
    const dates = this.extractDates(text);

    switch (documentType) {
      case 'AADHAAR': {
        const uidMatch = text.match(/\b\d{4}\s\d{4}\s\d{4}\b/) || text.match(/\b\d{12}\b/);
        if (uidMatch) {
          fields.documentNumber = uidMatch[0];
          fields.maskedNumber = `XXXX XXXX ${uidMatch[0].replace(/\s/g, '').slice(-4)}`;
        }
        const dobMatch = text.match(/(?:DOB|Date of Birth|Birth)\s*[:\-\s]\s*(\d{1,2}[/-]\d{1,2}[/-]\d{4})/i);
        if (dobMatch) {
          fields.dateOfBirth = dobMatch[1];
        } else if (dates.length > 0) {
          fields.dateOfBirth = dates[0];
        }
        const genderMatch = text.match(/\b(MALE|FEMALE|TRANSGENDER|Male|Female)\b/i);
        if (genderMatch) {
          fields.gender = genderMatch[1].toUpperCase();
        }
        fields.name = this.extractProbableName(text, ['government of india', 'aadhaar', 'uidai']);
        break;
      }

      case 'PAN': {
        const panMatch = text.toUpperCase().match(/\b[A-Z]{5}[0-9]{4}[A-Z]\b/);
        if (panMatch) {
          fields.panNumber = panMatch[0];
          fields.documentNumber = panMatch[0];
        }
        if (dates.length > 0) {
          fields.dateOfBirth = dates[0];
        }
        fields.name = this.extractProbableName(text, ['income tax department', 'govt of india', 'permanent account']);
        break;
      }

      case 'PASSPORT': {
        const passMatch = text.toUpperCase().match(/\b[A-PR-WYa-pr-wy][1-9]\d\s?\d{4}[1-9]\b/) || text.toUpperCase().match(/\b[A-Z][0-9]{7}\b/);
        if (passMatch) {
          fields.passportNumber = passMatch[0];
          fields.documentNumber = passMatch[0];
        }
        fields.nationality = text.toUpperCase().includes('INDIAN') ? 'INDIAN' : 'OTHER';
        if (dates.length >= 2) {
          fields.issueDate = dates[0];
          fields.expiryDate = dates[1];
        } else if (dates.length === 1) {
          fields.expiryDate = dates[0];
        }
        fields.name = this.extractProbableName(text, ['republic of india', 'passport', 'given name']);
        break;
      }

      case 'DRIVING_LICENCE': {
        const dlMatch = text.match(/\b[A-Z]{2}[- ]?[0-9]{2}[- ]?[0-9]{4}[- ]?[0-9]{7}\b/) ||
          text.match(/\b[A-Z]{2}[0-9]{13,15}\b/) ||
          text.match(/\b[A-Z]{2}[0-9]{2}\s?[0-9]{11}\b/);
        if (dlMatch) {
          fields.licenseNumber = dlMatch[0];
          fields.documentNumber = dlMatch[0];
        }
        if (dates.length >= 2) {
          fields.issueDate = dates[0];
          fields.expiryDate = dates[1];
        } else if (dates.length === 1) {
          fields.expiryDate = dates[0];
        }
        const classMatch = text.match(/\b(MCWG|LMV|MCWOG|TRANS|HMV|HPMV)\b/g);
        if (classMatch) {
          fields.vehicleClasses = Array.from(new Set(classMatch)).join(', ');
        }
        fields.name = this.extractProbableName(text, ['driving licence', 'union of india', 'transport department']);
        break;
      }

      case 'INSURANCE': {
        const polMatch = text.match(/(?:policy\s*(?:no|number|#))\s*[:\-\s]*([A-Z0-9\/-]+)/i);
        if (polMatch) {
          fields.policyNumber = polMatch[1].trim();
          fields.documentNumber = polMatch[1].trim();
        }
        if (dates.length >= 2) {
          fields.issueDate = dates[0];
          fields.expiryDate = dates[1];
        } else if (dates.length === 1) {
          fields.expiryDate = dates[0];
        }
        fields.holderName = this.extractProbableName(text, ['insurance', 'policy schedule', 'certificate of insurance']);
        break;
      }

      case 'VEHICLE': {
        const regMatch = text.toUpperCase().match(/\b[A-Z]{2}[0-9]{1,2}[A-Z]{1,3}[0-9]{4}\b/);
        if (regMatch) {
          fields.registrationNumber = regMatch[0];
          fields.documentNumber = regMatch[0];
        }
        const chassisMatch = text.match(/(?:chassis\s*(?:no|number|#))\s*[:\-\s]*([A-Z0-9]+)/i);
        if (chassisMatch) {
          fields.chassisNumber = chassisMatch[1];
        }
        const engineMatch = text.match(/(?:engine\s*(?:no|number|#))\s*[:\-\s]*([A-Z0-9]+)/i);
        if (engineMatch) {
          fields.engineNumber = engineMatch[1];
        }
        break;
      }

      default: {
        if (dates.length > 0) {
          fields.detectedDates = dates;
          if (dates.length > 1) {
            fields.issueDate = dates[0];
            fields.expiryDate = dates[dates.length - 1];
          } else {
            fields.issueDate = dates[0];
          }
        }
        break;
      }
    }

    return fields;
  }

  async summarizeDocument(documentType: string, fields: Record<string, any>): Promise<string> {
    const name = fields.name || fields.holderName || fields.ownerName;
    const expiry = fields.expiryDate;
    const number = fields.documentNumber || fields.panNumber || fields.licenseNumber || fields.policyNumber;

    switch (documentType) {
      case 'DRIVING_LICENCE':
        return `Government-issued driving licence${name ? ` for ${name}` : ''}.${number ? ` No: ${number}.` : ''}${expiry ? ` Valid until ${expiry}.` : ''}`;
      case 'PASSPORT':
        return `Republic of India official passport${name ? ` for ${name}` : ''}.${number ? ` No: ${number}.` : ''}${expiry ? ` Valid until ${expiry}.` : ''}`;
      case 'PAN':
        return `Permanent Account Number (PAN) card${name ? ` for ${name}` : ''}.${number ? ` PAN: ${number}.` : ''}`;
      case 'AADHAAR':
        return `Unique Identification Authority of India (Aadhaar) card${name ? ` for ${name}` : ''}.`;
      case 'INSURANCE':
        return `Insurance policy document${number ? ` #${number}` : ''}.${expiry ? ` Expires on ${expiry}.` : ''}`;
      case 'VEHICLE':
        return `Vehicle registration certificate${number ? ` (${number})` : ''}.`;
      case 'EDUCATION_CERTIFICATE':
        return `Academic qualification or degree certificate${name ? ` issued to ${name}` : ''}.`;
      case 'MARKSHEET':
        return `Academic mark sheet or grade report.`;
      case 'BANK':
        return `Financial account statement or bank document.`;
      case 'MEDICAL':
        return `Medical record or clinical diagnosis document.`;
      default:
        return `Verified digital vault document.`;
    }
  }

  private extractDates(text: string): string[] {
    const dates: string[] = [];
    // Format: DD/MM/YYYY or DD-MM-YYYY or DD.MM.YYYY
    const dmyPattern = /\b([0-3]?[0-9])[./-]([0-1]?[0-9])[./-]((?:19|20)\d{2})\b/g;
    let match;
    while ((match = dmyPattern.exec(text)) !== null) {
      const day = match[1].padStart(2, '0');
      const month = match[2].padStart(2, '0');
      const year = match[3];
      dates.push(`${day}/${month}/${year}`);
    }

    // Format: DD Mon YYYY
    const textDatePattern = /\b([0-3]?[0-9])\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+((?:19|20)\d{2})\b/gi;
    while ((match = textDatePattern.exec(text)) !== null) {
      dates.push(`${match[1]} ${match[2]} ${match[3]}`);
    }

    return Array.from(new Set(dates));
  }

  private extractProbableName(text: string, stopPhrases: string[]): string | undefined {
    const lines = text.split(/\r?\n/).map((l) => l.trim()).filter((l) => l.length > 2);
    for (const line of lines) {
      const lower = line.toLowerCase();
      // Skip lines that have stop phrases
      if (stopPhrases.some((phrase) => lower.includes(phrase))) continue;
      // Skip lines that have digits or symbols
      if (/\d/.test(line)) continue;
      // Look for 2-4 capitalized words that look like a person's name
      if (/^[A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+){1,3}$/.test(line)) {
        return line;
      }
    }
    return undefined;
  }
}
