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

    const schoolFolder = path.join(this.uploadDir, schoolId);
    if (!fs.existsSync(schoolFolder)) {
      fs.mkdirSync(schoolFolder, { recursive: true });
    }

    const ext = path.extname(file.originalname);
    const uniqueName = `${Date.now()}-${Math.random().toString(36).substring(2, 9)}${ext}`;
    const targetPath = path.join(schoolFolder, uniqueName);

    fs.writeFileSync(targetPath, file.buffer);

    const relativeUrl = `/uploads/${schoolId}/${uniqueName}`;
    return {
      originalName: file.originalname,
      fileName: uniqueName,
      mimeType: file.mimetype,
      sizeBytes: file.size,
      url: relativeUrl,
    };
  }
}

