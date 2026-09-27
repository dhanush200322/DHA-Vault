-- AlterTable
ALTER TABLE "devices" ADD COLUMN     "appVersion" TEXT,
ADD COLUMN     "isLocked" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "lastSyncedAt" TIMESTAMP(3),
ADD COLUMN     "syncStatus" TEXT NOT NULL DEFAULT 'IDLE';

-- AlterTable
ALTER TABLE "document_versions" ADD COLUMN     "checksum" TEXT,
ADD COLUMN     "cloudObjectKey" TEXT,
ADD COLUMN     "deviceId" TEXT,
ADD COLUMN     "encryptionVersion" INTEGER NOT NULL DEFAULT 1;

-- AlterTable
ALTER TABLE "documents" ADD COLUMN     "checksum" TEXT,
ADD COLUMN     "cloudObjectKey" TEXT,
ADD COLUMN     "encryptionVersion" INTEGER NOT NULL DEFAULT 1,
ADD COLUMN     "lastSyncedAt" TIMESTAMP(3),
ADD COLUMN     "syncStatus" TEXT NOT NULL DEFAULT 'SYNCED';

-- CreateTable
CREATE TABLE "sync_conflicts" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "documentId" TEXT NOT NULL,
    "localVersionId" TEXT,
    "remoteVersionId" TEXT,
    "status" TEXT NOT NULL DEFAULT 'OPEN',
    "resolution" TEXT,
    "resolvedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "sync_conflicts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cloud_backups" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "backupStatus" TEXT NOT NULL DEFAULT 'COMPLETED',
    "totalDocuments" INTEGER NOT NULL DEFAULT 0,
    "totalBytes" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "storageProvider" TEXT NOT NULL DEFAULT 'local',
    "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completedAt" TIMESTAMP(3),
    "errorDetails" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "cloud_backups_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "sync_conflicts_userId_status_idx" ON "sync_conflicts"("userId", "status");

-- CreateIndex
CREATE INDEX "sync_conflicts_documentId_idx" ON "sync_conflicts"("documentId");

-- CreateIndex
CREATE INDEX "cloud_backups_userId_idx" ON "cloud_backups"("userId");

-- CreateIndex
CREATE INDEX "cloud_backups_backupStatus_idx" ON "cloud_backups"("backupStatus");

-- CreateIndex
CREATE INDEX "documents_syncStatus_idx" ON "documents"("syncStatus");

-- AddForeignKey
ALTER TABLE "sync_conflicts" ADD CONSTRAINT "sync_conflicts_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sync_conflicts" ADD CONSTRAINT "sync_conflicts_documentId_fkey" FOREIGN KEY ("documentId") REFERENCES "documents"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cloud_backups" ADD CONSTRAINT "cloud_backups_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
