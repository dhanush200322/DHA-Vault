import { Controller, Get, Query } from '@nestjs/common';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { SearchService, SmartSearchQueryDto } from './search.service';

@Controller('search')
export class SearchController {
  constructor(private readonly searchService: SearchService) {}

  @Get()
  async search(
    @CurrentUser('userId') userId: string,
    @Query('q') query: string,
    @Query('categoryId') categoryId?: string,
    @Query('documentType') documentType?: string,
    @Query('isFavorite') isFavorite?: string,
    @Query('isArchived') isArchived?: string,
    @Query('isExpired') isExpired?: string,
    @Query('isExpiringSoon') isExpiringSoon?: string,
    @Query('year') year?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    const filters: SmartSearchQueryDto = {
      q: query,
      categoryId,
      documentType,
      isFavorite: isFavorite !== undefined ? isFavorite === 'true' : undefined,
      isArchived: isArchived !== undefined ? isArchived === 'true' : undefined,
      isExpired: isExpired !== undefined ? isExpired === 'true' : undefined,
      isExpiringSoon: isExpiringSoon !== undefined ? isExpiringSoon === 'true' : undefined,
      year: year ? parseInt(year, 10) : undefined,
      limit: limit ? parseInt(limit, 10) : undefined,
      offset: offset ? parseInt(offset, 10) : undefined,
    };

    return this.searchService.globalSearch(userId, query || '', filters);
  }
}
