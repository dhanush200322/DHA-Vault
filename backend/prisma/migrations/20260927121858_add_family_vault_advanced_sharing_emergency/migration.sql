-- CreateTable
CREATE TABLE "family_vaults" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "ownerId" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'ACTIVE',
    "settings" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "family_vaults_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "family_memberships" (
    "id" TEXT NOT NULL,
    "familyVaultId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "role" TEXT NOT NULL DEFAULT 'MEMBER',
    "status" TEXT NOT NULL DEFAULT 'ACTIVE',
    "invitedBy" TEXT,
    "joinedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "family_memberships_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "family_invitations" (
    "id" TEXT NOT NULL,
    "familyVaultId" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "role" TEXT NOT NULL DEFAULT 'MEMBER',
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "invitedById" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "family_invitations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "family_document_access" (
    "id" TEXT NOT NULL,
    "familyVaultId" TEXT NOT NULL,
    "documentId" TEXT NOT NULL,
    "sharedById" TEXT NOT NULL,
    "targetUserId" TEXT,
    "permissions" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "family_document_access_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "document_shares" (
    "id" TEXT NOT NULL,
    "documentId" TEXT NOT NULL,
    "ownerId" TEXT NOT NULL,
    "recipientUserId" TEXT,
    "recipientEmail" TEXT,
    "permissions" JSONB NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'ACTIVE',
    "keyEnvelope" JSONB,
    "allowDownload" BOOLEAN NOT NULL DEFAULT true,
    "maxViews" INTEGER,
    "viewCount" INTEGER NOT NULL DEFAULT 0,
    "watermarkText" TEXT,
    "expiresAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "document_shares_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "emergency_access" (
    "id" TEXT NOT NULL,
    "ownerId" TEXT NOT NULL,
    "delegateUserId" TEXT,
    "delegateEmail" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "activationDelayHours" INTEGER NOT NULL DEFAULT 48,
    "triggerRequestedAt" TIMESTAMP(3),
    "activatedAt" TIMESTAMP(3),
    "expiresAt" TIMESTAMP(3),
    "scope" TEXT NOT NULL DEFAULT 'SELECTED_DOCUMENTS',
    "selectedDocIds" JSONB,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "emergency_access_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "recovery_delegations" (
    "id" TEXT NOT NULL,
    "ownerId" TEXT NOT NULL,
    "delegateUserId" TEXT,
    "delegateEmail" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "recoveryPayload" JSONB,
    "expiresAt" TIMESTAMP(3),
    "acceptedAt" TIMESTAMP(3),
    "revokedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "recovery_delegations_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "family_vaults_ownerId_idx" ON "family_vaults"("ownerId");

-- CreateIndex
CREATE INDEX "family_vaults_status_idx" ON "family_vaults"("status");

-- CreateIndex
CREATE INDEX "family_memberships_familyVaultId_idx" ON "family_memberships"("familyVaultId");

-- CreateIndex
CREATE INDEX "family_memberships_userId_idx" ON "family_memberships"("userId");

-- CreateIndex
CREATE INDEX "family_memberships_role_idx" ON "family_memberships"("role");

-- CreateIndex
CREATE INDEX "family_memberships_status_idx" ON "family_memberships"("status");

-- CreateIndex
CREATE UNIQUE INDEX "family_memberships_familyVaultId_userId_key" ON "family_memberships"("familyVaultId", "userId");

-- CreateIndex
CREATE UNIQUE INDEX "family_invitations_tokenHash_key" ON "family_invitations"("tokenHash");

-- CreateIndex
CREATE INDEX "family_invitations_familyVaultId_idx" ON "family_invitations"("familyVaultId");

-- CreateIndex
CREATE INDEX "family_invitations_email_idx" ON "family_invitations"("email");

-- CreateIndex
CREATE INDEX "family_invitations_status_idx" ON "family_invitations"("status");

-- CreateIndex
CREATE INDEX "family_invitations_expiresAt_idx" ON "family_invitations"("expiresAt");

-- CreateIndex
CREATE INDEX "family_document_access_familyVaultId_idx" ON "family_document_access"("familyVaultId");

-- CreateIndex
CREATE INDEX "family_document_access_documentId_idx" ON "family_document_access"("documentId");

-- CreateIndex
CREATE INDEX "family_document_access_sharedById_idx" ON "family_document_access"("sharedById");

-- CreateIndex
CREATE INDEX "family_document_access_targetUserId_idx" ON "family_document_access"("targetUserId");

-- CreateIndex
CREATE UNIQUE INDEX "family_document_access_familyVaultId_documentId_targetUserI_key" ON "family_document_access"("familyVaultId", "documentId", "targetUserId");

-- CreateIndex
CREATE INDEX "document_shares_ownerId_idx" ON "document_shares"("ownerId");

-- CreateIndex
CREATE INDEX "document_shares_recipientUserId_idx" ON "document_shares"("recipientUserId");

-- CreateIndex
CREATE INDEX "document_shares_recipientEmail_idx" ON "document_shares"("recipientEmail");

-- CreateIndex
CREATE INDEX "document_shares_documentId_idx" ON "document_shares"("documentId");

-- CreateIndex
CREATE INDEX "document_shares_status_idx" ON "document_shares"("status");

-- CreateIndex
CREATE INDEX "emergency_access_ownerId_idx" ON "emergency_access"("ownerId");

-- CreateIndex
CREATE INDEX "emergency_access_delegateUserId_idx" ON "emergency_access"("delegateUserId");

-- CreateIndex
CREATE INDEX "emergency_access_delegateEmail_idx" ON "emergency_access"("delegateEmail");

-- CreateIndex
CREATE INDEX "emergency_access_status_idx" ON "emergency_access"("status");

-- CreateIndex
CREATE INDEX "recovery_delegations_ownerId_idx" ON "recovery_delegations"("ownerId");

-- CreateIndex
CREATE INDEX "recovery_delegations_delegateUserId_idx" ON "recovery_delegations"("delegateUserId");

-- CreateIndex
CREATE INDEX "recovery_delegations_delegateEmail_idx" ON "recovery_delegations"("delegateEmail");

-- CreateIndex
CREATE INDEX "recovery_delegations_status_idx" ON "recovery_delegations"("status");

-- AddForeignKey
ALTER TABLE "family_vaults" ADD CONSTRAINT "family_vaults_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_memberships" ADD CONSTRAINT "family_memberships_familyVaultId_fkey" FOREIGN KEY ("familyVaultId") REFERENCES "family_vaults"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_memberships" ADD CONSTRAINT "family_memberships_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_invitations" ADD CONSTRAINT "family_invitations_familyVaultId_fkey" FOREIGN KEY ("familyVaultId") REFERENCES "family_vaults"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_invitations" ADD CONSTRAINT "family_invitations_invitedById_fkey" FOREIGN KEY ("invitedById") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_document_access" ADD CONSTRAINT "family_document_access_familyVaultId_fkey" FOREIGN KEY ("familyVaultId") REFERENCES "family_vaults"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_document_access" ADD CONSTRAINT "family_document_access_documentId_fkey" FOREIGN KEY ("documentId") REFERENCES "documents"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_document_access" ADD CONSTRAINT "family_document_access_sharedById_fkey" FOREIGN KEY ("sharedById") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_document_access" ADD CONSTRAINT "family_document_access_targetUserId_fkey" FOREIGN KEY ("targetUserId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "document_shares" ADD CONSTRAINT "document_shares_documentId_fkey" FOREIGN KEY ("documentId") REFERENCES "documents"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "document_shares" ADD CONSTRAINT "document_shares_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "document_shares" ADD CONSTRAINT "document_shares_recipientUserId_fkey" FOREIGN KEY ("recipientUserId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "emergency_access" ADD CONSTRAINT "emergency_access_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "emergency_access" ADD CONSTRAINT "emergency_access_delegateUserId_fkey" FOREIGN KEY ("delegateUserId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "recovery_delegations" ADD CONSTRAINT "recovery_delegations_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "recovery_delegations" ADD CONSTRAINT "recovery_delegations_delegateUserId_fkey" FOREIGN KEY ("delegateUserId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
