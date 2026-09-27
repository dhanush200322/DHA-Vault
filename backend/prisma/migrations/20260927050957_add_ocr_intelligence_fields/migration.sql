-- AlterTable
ALTER TABLE "documents" ADD COLUMN     "extractedFields" JSONB,
ADD COLUMN     "ocrConfidence" DOUBLE PRECISION,
ADD COLUMN     "ocrProcessedAt" TIMESTAMP(3),
ADD COLUMN     "ocrProvider" TEXT,
ADD COLUMN     "ocrStatus" TEXT NOT NULL DEFAULT 'PENDING';

-- CreateIndex
CREATE INDEX "documents_ocrStatus_idx" ON "documents"("ocrStatus");
