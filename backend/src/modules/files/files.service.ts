import { Injectable, BadRequestException } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';

@Injectable()
export class FilesService {
  private readonly uploadDir = path.join(process.cwd(), 'public', 'uploads');

  constructor() {
    if (!fs.existsSync(this.uploadDir)) {
      fs.mkdirSync(this.uploadDir, { recursive: true });
    }
  }

  saveUploadedFile(file: Express.Multer.File, schoolId: string) {
    if (!file) {
      throw new BadRequestException('No file provided for upload');
    }

    const safeSchoolId = path.basename(schoolId).replace(/[^a-zA-Z0-9_-]/g, '');
    if (!safeSchoolId) {
      throw new BadRequestException('Invalid school identifier');
    }

    const schoolFolder = path.join(this.uploadDir, safeSchoolId);
    if (!fs.existsSync(schoolFolder)) {
      fs.mkdirSync(schoolFolder, { recursive: true });
    }

    const ext = path.extname(file.originalname).toLowerCase();
    const safeExt = ext.replace(/[^a-z0-9.]/g, '');
    const uniqueName = `${Date.now()}-${Math.random().toString(36).substring(2, 9)}${safeExt}`;
    const targetPath = path.join(schoolFolder, uniqueName);

    fs.writeFileSync(targetPath, file.buffer);

    const relativeUrl = `/uploads/${safeSchoolId}/${uniqueName}`;
    return {
      originalName: path.basename(file.originalname),
      fileName: uniqueName,
      mimeType: file.mimetype,
      sizeBytes: file.size,
      url: relativeUrl,
    };
  }
}

