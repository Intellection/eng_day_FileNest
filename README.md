# FileNest 🗄️ - Your Personal File Cache

A secure, lightweight file upload service with **sexy anti-virus protection** and beautiful previews.

## 🚀 Quick Start

### Option 1: Easy Setup (Recommended)
```bash
git clone <repo-url>
cd eng_day_FileNest

# OPTIONAL: Start the sexy anti-virus scanner
# The app will run without Docker. Just not the anti-virus
docker-compose up -d clamav

# Setup Rails
bundle install
bin/rails db:create db:migrate
bin/rails server
```

Visit `http://localhost:3000` and start uploading! 🎉

### OPTIONAL - Option 2: Skip Virus Scanning (Development)
```bash
SKIP_VIRUS_SCAN=true bin/rails server
```

## ✨ Best Features

### 🛡️ Sexy Anti-Virus Protection
- **Real-time virus scanning** with ClamAV integration
- **Every file is scanned** before it touches your system
- **EICAR test detection** - try uploading a test virus!
- **Fail-safe design** - infected files are blocked instantly
- **Dockerized scanner** - keeps your system clean

### 🖼️ Beautiful File Previews
- **Image previews** - JPG, PNG, GIF, SVG support
- **Text file viewing** - TXT, MD, CSV files
- **Modal preview** with full-screen support
- **Instant loading** with smooth animations

### ✏️ Smart File Renaming
- **Click to rename** any file instantly
- **Real-time validation** of file names
- **Keyboard shortcuts** (Enter to save, Escape to cancel)
- **Extension protection** - keeps files safe

### 📥 Secure Downloads
- **One-click downloads** with proper file names
- **Owner-only access** - your files stay yours
- **Bulk operations** coming soon

### 🎨 Modern UI
- **Drag & drop** file uploads
- **Real-time progress** bars
- **Responsive design** works on all devices
- **Material Design** with smooth animations

## 🔧 Requirements

- Ruby 3.3.5+
- PostgreSQL
- Docker (for the sexy anti-virus)

## 📁 Supported Files

| Type | Extensions | Max Size |
|------|------------|----------|
| **Images** | JPG, PNG, GIF, SVG | 2MB |
| **Documents** | TXT, MD, CSV | 2MB |

## 🧪 Test the Anti-Virus

Want to see the sexy anti-virus in action?

```bash
# Quick virus test
ruby script/simple_virus_test.rb

# Full test suite
ruby script/test_virus_scanning.rb
```

Try uploading the EICAR test virus - it gets blocked instantly! 🦠❌

## 🔐 Security Features

- **JWT authentication** - secure API access
- **File ownership** - users only see their files
- **Virus scanning** - every upload is checked
- **Input validation** - malicious files blocked
- **CORS protection** - API security built-in

## 📱 Usage

1. **Register/Login** - create your account
2. **Drag & Drop** - upload files instantly
3. **Preview** - click the eye icon to view files
4. **Rename** - click any filename to edit
5. **Download** - grab your files anytime
6. **Delete** - remove files you don't need

## 🚢 Production Setup

```bash
export RAILS_ENV=production
export SECRET_KEY_BASE=your_secret_key
export DATABASE_URL=your_database_url
export CLAMAV_HOST=your_clamav_host
export REQUIRE_VIRUS_SCAN=true

bin/rails db:migrate
bin/rails server
```

## 🆘 Troubleshooting

**ClamAV not working?**
```bash
docker-compose logs clamav
```

**Database issues?**
```bash
bin/rails db:reset
```

**Want to skip virus scanning?**
```bash
SKIP_VIRUS_SCAN=true bin/rails server
```

---

**FileNest** - Simple. Secure. Sexy anti-virus included. 🛡️✨
