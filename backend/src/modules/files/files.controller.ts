import {
  Controller,
  Post,
  UseInterceptors,
  UploadedFile,
  UseGuards,
  BadRequestException,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiConsumes, ApiBody } from '@nestjs/swagger';
import { FileInterceptor } from '@nestjs/platform-express';
import { FilesService } from './files.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentSchoolId } from '../../common/decorators/current-user.decorator';

@ApiTags('Tenant Storage & File Uploads')
@ApiBearerAuth()
@Controller('files')
@UseGuards(JwtAuthGuard)
export class FilesController {
  constructor(private filesService: FilesService) {}

  @Post('upload')
  @ApiOperation({ summary: 'Upload file attachment (max 25MB: PDF, Office docs, Images, CSV, ZIP)' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: {
          type: 'string',
          format: 'binary',
        },
      },
    },
  })
  @ApiResponse({ status: 201, description: 'File uploaded successfully' })
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: 25 * 1024 * 1024 }, // 25 MB max limit
      fileFilter: (req, file, cb) => {
        // Allow pdf, doc, images, xlsx, txt
        const allowed = /\.(pdf|docx?|xlsx?|csv|png|jpe?g|txt|zip)$/i;
        if (!file.originalname.match(allowed)) {
          return cb(new BadRequestException('File type not supported for upload'), false);
        }
        cb(null, true);
      },
    }),
  )
  uploadFile(
    @CurrentSchoolId() schoolId: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    const data = this.filesService.saveUploadedFile(file, schoolId);
    return { data };
  }
}
