import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

export interface SmartSearchQueryDto {
  q?: string;
  categoryId?: string;
  documentType?: string;
  isFavorite?: boolean;
  isArchived?: boolean;
  isExpired?: boolean;
  isExpiringSoon?: boolean;
  year?: number;
  limit?: number;
  offset?: number;
}

@Injectable()
export class SearchService {
  constructor(private readonly prisma: PrismaService) {}

  async globalSearch(userId: string, queryStr: string, filters: SmartSearchQueryDto = {}) {
    const rawQuery = (queryStr || '').trim();
    const queryLower = rawQuery.toLowerCase();

    // 1. Smart Intent Detection
    let filterExpiringSoon = filters.isExpiringSoon;
    let filterExpired = filters.isExpired;
    let extractedYear = filters.year;

    // Detect "expiring" or "expiring soon" intent in query
    if (queryLower.includes('expiring') || queryLower.includes('expir') || queryLower.includes('renew')) {
      filterExpiringSoon = true;
    }
    if (queryLower.includes('expired')) {
      filterExpired = true;
      filterExpiringSoon = false;
    }

    // Detect 4-digit year in query (e.g. "2027", "2026")
    const yearMatch = rawQuery.match(/\b(20\d{2})\b/);
    if (yearMatch) {
      extractedYear = parseInt(yearMatch[1], 10);
    }

    // Clean terms: remove stop-words from query for text matching
    const cleanTerm = rawQuery
      .replace(/documents?|expiring|expired|soon/gi, '')
      .trim();

    // 2. Build Prisma Where Clause
    const where: any = {
      userId,
      isArchived: filters.isArchived ?? false,
    };

    if (filters.categoryId) {
      where.categoryId = filters.categoryId;
    }

    if (filters.documentType) {
      where.documentType = filters.documentType;
    }

    if (filters.isFavorite !== undefined) {
      where.isFavorite = filters.isFavorite;
    }

    const now = new Date();
    if (filterExpired) {
      where.expiryDate = { lt: now };
    } else if (filterExpiringSoon) {
      const in30Days = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
      where.expiryDate = { gte: now, lte: in30Days };
    } else if (extractedYear) {
      const startOfYear = new Date(Date.UTC(extractedYear, 0, 1));
      const endOfYear = new Date(Date.UTC(extractedYear, 11, 31, 23, 59, 59));
      where.OR = [
        { expiryDate: { gte: startOfYear, lte: endOfYear } },
        { issueDate: { gte: startOfYear, lte: endOfYear } },
      ];
    }

    // If there is still a text search term after intent detection
    if (cleanTerm.length > 0) {
      const termOrs: any[] = [
        { title: { contains: cleanTerm, mode: 'insensitive' } },
        { description: { contains: cleanTerm, mode: 'insensitive' } },
        { extractedText: { contains: cleanTerm, mode: 'insensitive' } },
        { documentType: { contains: cleanTerm, mode: 'insensitive' } },
        { tags: { some: { tag: { name: { contains: cleanTerm, mode: 'insensitive' } } } } },
      ];

      if (where.OR) {
        where.AND = [{ OR: where.OR }, { OR: termOrs }];
        delete where.OR;
      } else {
        where.OR = termOrs;
      }
    }

    // 3. Execute Searches concurrently
    const [documents, categories, tags] = await Promise.all([
      this.prisma.document.findMany({
        where,
        take: filters.limit || 20,
        skip: filters.offset || 0,
        orderBy: { updatedAt: 'desc' },
        select: {
          id: true,
          title: true,
          description: true,
          documentType: true,
          fileType: true,
          fileSize: true,
          mimeType: true,
          storagePath: true,
          thumbnailPath: true,
          extractedText: true,
          extractedFields: true,
          ocrStatus: true,
          ocrConfidence: true,
          issueDate: true,
          expiryDate: true,
          isFavorite: true,
          isArchived: true,
          createdAt: true,
          updatedAt: true,
          category: {
            select: { id: true, name: true, color: true, icon: true },
          },
          tags: {
            select: { tag: { select: { id: true, name: true, color: true } } },
          },
        },
      }),
      cleanTerm.length > 0
        ? this.prisma.category.findMany({
            where: {
              userId,
              name: { contains: cleanTerm, mode: 'insensitive' },
            },
            take: 5,
            select: { id: true, name: true, icon: true, color: true },
          })
        : [],
      cleanTerm.length > 0
        ? this.prisma.tag.findMany({
            where: {
              userId,
              name: { contains: cleanTerm, mode: 'insensitive' },
            },
            take: 5,
            select: { id: true, name: true, color: true },
          })
        : [],
    ]);

    // 4. Enrich matched documents with highlights/snippets
    const enrichedDocs = documents.map((doc) => {
      let snippet: string | null = null;
      let matchReason = 'Match found';

      if (cleanTerm.length > 0 && doc.extractedText) {
        const idx = doc.extractedText.toLowerCase().indexOf(cleanTerm.toLowerCase());
        if (idx !== -1) {
          const start = Math.max(0, idx - 40);
          const end = Math.min(doc.extractedText.length, idx + cleanTerm.length + 40);
          snippet = `...${doc.extractedText.slice(start, end).trim()}...`;
          matchReason = 'Matched in extracted document text';
        }
      }

      if (filterExpiringSoon) {
        matchReason = 'Expiring in less than 30 days';
      } else if (filterExpired) {
        matchReason = 'Expired document';
      } else if (extractedYear) {
        matchReason = `Dated in ${extractedYear}`;
      }

      return {
        ...doc,
        snippet,
        matchReason,
      };
    });

    return {
      query: rawQuery,
      totalMatches: enrichedDocs.length,
      documents: enrichedDocs,
      categories,
      tags,
    };
  }
}
