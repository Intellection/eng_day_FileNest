# FileNest - Your Personal File Cache 🗄️

[![Ruby](https://img.shields.io/badge/ruby-3.3.5-red.svg)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/rails-8.0.2-red.svg)](https://rubyonrails.org/)
[![PostgreSQL](https://img.shields.io/badge/postgresql-latest-blue.svg)](https://www.postgresql.org/)

## 🧠 Welcome to FileNest

FileNest is a lightweight, secure file upload and access API designed as your personal "nest" for screenshots, quick notes, and files. Think of it as a private, temporary cache where you can store and access your files securely - but only your own.

## 🎯 Key Features

### 🔐 Security First
- JWT-based authentication for all endpoints
- Strict file ownership enforcement
- Users can only access their own files
- Secure password hashing with bcrypt

### 📤 Smart File Upload
- **Supported formats**: JPG, PNG, GIF, SVG, TXT, MD, CSV
- **File size limit**: 2MB maximum
- **Automatic validation**: File type and size checking
- **Unique identifiers**: UUID-based file tracking
- **MIME type detection**: Automatic content type identification

### 📄 File Management
- List your uploaded files with metadata
- Download with strict ownership verification
- Delete files you no longer need
- Clean metadata display (filename, size, upload date, type)
- File preview support for images

### 🎨 Frontend Interface
- Clean, responsive web interface
- Drag & drop file upload
- Real-time file listing
- User authentication forms
- File statistics and management

## 🚀 Technologies

- **Backend**: Rails 8.0.2 API
- **Language**: Ruby 3.3.5
- **Database**: PostgreSQL
- **Authentication**: JWT tokens with bcrypt
- **File Processing**: Marcel for MIME type detection
- **File Storage**: Active Storage with local/cloud support
- **Image Processing**: ImageMagick/libvips via image_processing gem
- **CORS**: Rack-CORS for cross-origin requests

## 📋 API Endpoints

### Authentication
- `POST /auth/login` - User login
- `POST /auth/register` - User registration

### File Operations
- `POST /upload` - Upload a new file
- `GET /files` - List user's files
- `GET /files/:id` - Get file details
- `GET /files/:id/download` - Download a specific file
- `DELETE /files/:id` - Delete a file

### System
- `GET /health` - Health check endpoint

## 🛠️ Setup & Installation

### Prerequisites
- Ruby 3.3.5
- PostgreSQL
- ImageMagick or libvips (for image processing)

### Installation

1. **Clone and setup the application**:
```bash
cd snapvault
bundle install
```

2. **Database setup**:
```bash
bin/rails db:create
bin/rails db:migrate
```

3. **Start the server**:
```bash
bin/rails server
```

The application will be available at `http://localhost:3000`

### Quick Start with Docker

```bash
# Build and run with Docker
docker build -t snapvault .
docker run -p 3000:3000 snapvault
```

## 🏃‍♂️ Usage

### Web Interface
1. Visit `http://localhost:3000` in your browser
2. Register a new account or login
3. Upload files using drag & drop or file selector
4. View, download, or delete your files

### API Usage

#### Register a user
```bash
curl -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"John Doe","email":"john@example.com","password":"password123"}'
```

#### Login
```bash
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"john@example.com","password":"password123"}'
```

#### Upload a file
```bash
curl -X POST http://localhost:3000/upload \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "file=@/path/to/your/file.png"
```

#### List files
```bash
curl -X GET http://localhost:3000/files \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## 🧪 Testing

Run the test suite:
```bash
bin/rails test
```

Run with coverage:
```bash
COVERAGE=true bin/rails test
```

## 🔧 Development

### Code Quality
```bash
# Run linter
bin/rubocop

# Auto-fix issues
bin/rubocop -A

# Security audit
bin/brakeman
```

### Console Access
```bash
bin/rails console
```

### Database Console
```bash
bin/rails dbconsole
```

## 📁 Project Structure

```
snapvault/
├── app/
│   ├── controllers/         # API controllers
│   │   ├── auth_controller.rb
│   │   ├── files_controller.rb
│   │   └── uploads_controller.rb
│   ├── models/             # Data models
│   │   ├── user.rb
│   │   └── user_file.rb
│   └── services/           # Business logic
│       ├── auth/
│       └── file_processing/
├── config/                 # Application configuration
├── db/                     # Database files
├── public/                 # Static files and frontend
└── storage/               # File storage
```

## 🛡️ Security Features

### Authentication & Authorization
- JWT tokens with expiration
- Password hashing with bcrypt (cost factor 12)
- CORS protection
- File ownership verification

### File Security
- MIME type validation
- File size limits (2MB max)
- Allowed file type restrictions
- Secure file storage with Active Storage

### API Security
- Rate limiting ready
- Input validation and sanitization
- Error handling without information leakage

## 📊 File Type Support

| Category | Extensions | MIME Types |
|----------|------------|------------|
| **Images** | JPG, PNG, GIF, SVG | image/jpeg, image/png, image/gif, image/svg+xml |
| **Documents** | TXT, MD | text/plain, text/markdown |
| **Data** | CSV | text/csv, application/csv |

**Maximum file size**: 2MB per file

## 🚢 Deployment

### Production Setup

1. **Environment Variables**:
```bash
export RAILS_ENV=production
export SECRET_KEY_BASE=your_secret_key
export DATABASE_URL=postgresql://user:pass@host:port/dbname
```

2. **Database Setup**:
```bash
RAILS_ENV=production bin/rails db:create db:migrate
```

3. **Asset Compilation**:
```bash
RAILS_ENV=production bin/rails assets:precompile
```

### Deployment Platforms

SnapVault is ready for deployment on:
- **Heroku**: `git push heroku main`
- **Railway**: Connect GitHub repository
- **DigitalOcean App Platform**: Use Dockerfile
- **AWS**: ECS/Elastic Beanstalk ready
- **Self-hosted**: Docker or direct deployment

### Docker Deployment

```bash
# Build production image
docker build -t filenest:latest .

# Run with environment variables
docker run -d -p 3000:3000 \
  -e RAILS_ENV=production \
  -e SECRET_KEY_BASE=your_secret \
  -e DATABASE_URL=your_db_url \
  filenest:latest
```

## 🔮 Future Enhancements

### Planned Features
- [ ] **File Sharing**: Temporary sharing links with expiration
- [ ] **File Previews**: In-browser preview for documents and images
- [ ] **Batch Operations**: Multiple file upload/download/delete
- [ ] **File Versioning**: Keep multiple versions of files
- [ ] **Advanced Search**: Search by filename, content, metadata
- [ ] **Tags & Categories**: Organize files with custom tags
- [ ] **File Collaboration**: Share files with other users
- [ ] **API Rate Limiting**: Prevent abuse with rate limiting
- [ ] **File Encryption**: End-to-end encryption for sensitive files
- [ ] **Audit Logs**: Track file access and modifications

### Scalability Improvements
- [ ] **Cloud Storage**: S3, Google Cloud, Azure integration
- [ ] **CDN Integration**: Fast file delivery worldwide
- [ ] **Database Optimization**: Indexing and query optimization
- [ ] **Caching Layer**: Redis for session and file metadata
- [ ] **Background Jobs**: Async file processing
- [ ] **Monitoring**: Application performance monitoring

### User Experience
- [ ] **Mobile App**: Native iOS/Android applications
- [ ] **Desktop App**: Electron-based desktop client
- [ ] **Browser Extension**: Quick screenshot upload
- [ ] **CLI Tool**: Command-line interface for power users

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass (`bin/rails test`)
6. Run the linter (`bin/rubocop`)
7. Commit your changes (`git commit -m 'Add amazing feature'`)
8. Push to the branch (`git push origin feature/amazing-feature`)
9. Open a Pull Request

### Development Guidelines
- Follow Ruby and Rails best practices
- Write comprehensive tests
- Update documentation for new features
- Ensure backward compatibility
- Use conventional commit messages

## 📄 License

FileNest is open source and available under the [MIT License](LICENSE).

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/filenest/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/filenest/discussions)
- **Email**: support@filenest.dev

## 🙏 Acknowledgments

- Rails team for the amazing framework
- Active Storage for file handling
- JWT for authentication tokens
- ImageMagick/libvips for image processing
- PostgreSQL for reliable data storage

---

**Built with ❤️ for developers who need a simple, secure file cache.**

*FileNest - Keep your files close, keep them secure.*