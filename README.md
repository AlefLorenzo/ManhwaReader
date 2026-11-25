# Manhwa Reader

A feature-rich iOS app for reading manhwa, manga, comics, and documents in CBZ, CB7, CBR, and PDF formats.

## Features

- **Multiple Format Support**: CBZ, CB7, CBR (ZIP/RAR/7z archives with images), and PDF
- **Manhwa Optimized**: Right-to-left reading direction by default
- **Reading Modes**: 
  - Right-to-Left (Manhwa/Manga)
  - Left-to-Right (Western comics)
  - Vertical Scroll (Webtoon style)
- **Gesture Controls**: Pinch to zoom, drag to pan, tap to toggle UI
- **Library Management**: Import files, organized library with covers
- **Progress Tracking**: Remembers last read page per book
- **Dark Mode**: Optimized for comfortable reading

## Screenshots

<!-- Add screenshots here -->

## Requirements

- iOS 17.0+
- Xcode 15.0+ (for building)
- Apple Developer Account (for device installation)

## Building the App

### Option 1: GitHub Actions (Recommended - No Mac Required)

1. Fork this repository
2. Go to Settings → Secrets and variables → Actions
3. Add the following secrets:
   - `APP_STORE_CONNECT_API_KEY` - Your App Store Connect API Key (p8 file content)
   - `APP_STORE_CONNECT_API_ISSUER` - Your API Key Issuer ID
   - `APP_STORE_CONNECT_API_KEY_ID` - Your API Key ID
   - `XTOOL_APPLE_ID` - Your Apple ID (alternative to API Key)
   - `XTOOL_PASSWORD` - Your Apple ID password or app-specific password
   - `IOS_DEVICE_UDID` - Your iPhone's UDID (for direct device deployment)
3. Go to Actions tab → "Build iOS App" → Run workflow
4. Download the IPA from Artifacts when build completes

### Option 2: Build on macOS with xtool

```bash
# Install xtool
curl -fsSL https://github.com/xtool-org/xtool/releases/download/2.0.0-beta.2/xtool.app.zip -o xtool.app.zip
unzip xtool.app.zip
sudo mv xtool.app /Applications/xtool.app
sudo ln -sf /Applications/xtool.app/Contents/Resources/bin/xtool /usr/local/bin/xtool

# Setup (authenticates with Apple)
xtool setup

# Build and run on simulator
cd ManhwaReader
xtool dev run --simulator

# Build for device (requires Apple Developer account)
xtool dev run --configuration release --udid YOUR_DEVICE_UDID
```

### Option 3: Build with Xcode

1. Open `ManhwaReader/Package.swift` in Xcode
2. Select your development team in Signing & Capabilities
3. Build and run on simulator or device

## Installing on iPhone

### Method 1: Direct Deploy (Apple Developer Account)
If you have a paid Apple Developer account ($99/year):
- Use `xtool dev run --udid YOUR_UDID` to install directly
- Or use Xcode to install

### Method 2: AltStore (Free, No Paid Account)
1. Install [AltStore](https://altstore.io/) on your computer
2. Connect iPhone via USB
3. Install AltStore on iPhone
4. Download the IPA from GitHub Actions artifacts
5. In AltStore, tap "My Apps" → "+" → Select the IPA
6. Trust the developer certificate in Settings → General → VPN & Device Management

### Method 3: Sideloadly (Free, Windows/macOS/Linux)
1. Download [Sideloadly](https://sideloadly.io/)
2. Connect iPhone via USB
3. Drag and drop the IPA into Sideloadly
4. Enter your Apple ID credentials
5. Click "Start"
6. Trust the certificate in Settings

### Method 4: TestFlight (For Testing)
1. Upload IPA to App Store Connect
2. Add yourself as internal tester
3. Install TestFlight on iPhone
4. Accept invite and install

## Project Structure

```
ManhwaReader/
├── .github/workflows/     # GitHub Actions CI/CD
├── Sources/ManhwaReader/
│   ├── Models/
│   │   ├── Book.swift         # Book data models
│   │   └── BookStore.swift    # Library management
│   ├── Views/
│   │   ├── ContentView.swift  # Main library view
│   │   ├── PDFReaderView.swift # PDF reading view
│   │   └── CBZReaderView.swift # CBZ/CBR/CB7 reading view
│   ├── ManhwaReaderApp.swift  # App entry point
│   └── ContentView.swift      # Main view
├── Package.swift            # Swift Package manifest
├── xtool.yml               # xtool configuration
└── README.md
```

## Dependencies

- **ZIPFoundation** - CBZ/CBR/CB7 archive handling
- **PDFKit** (iOS built-in) - PDF rendering
- **SwiftUI** - UI framework

## Supported Formats

| Format | Extension | Description |
|--------|-----------|-------------|
| CBZ | `.cbz` | ZIP archive with images |
| CB7 | `.cb7` | 7-Zip archive with images |
| CBR | `.cbr` | RAR archive with images |
| PDF | `.pdf` | Portable Document Format |

## Reading Directions

- **Right to Left** (Default): For manhwa, manga - pages advance right to left
- **Left to Right**: For western comics - pages advance left to right
- **Vertical Scroll**: For webtoons - continuous vertical scrolling

## Configuration

Edit `xtool.yml` to change the bundle identifier:

```yaml
version: 1
bundleID: com.yourname.ManhwaReader
```

## Troubleshooting

### Build Fails with "SDK not found"
Run `xtool setup` to install the Darwin SDK (requires Xcode.xip download)

### Can't Install on Device
- Ensure you have a valid provisioning profile
- Check that the bundle ID matches your provisioning profile
- Trust the developer certificate in Settings

### PDF Not Rendering
- Ensure the PDF is not password protected
- Try opening in Files app first to verify

### CBZ Not Loading
- Ensure the archive contains only image files
- Check that file extensions are .jpg, .jpeg, .png, .webp, .bmp, or .gif

## License

MIT License - See LICENSE file for details

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `swift test`
5. Submit a pull request

## Acknowledgments

- [xtool](https://github.com/xtool-org/xtool) - Cross-platform iOS build tool
- [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) - ZIP archive handling
- [PDFKit](https://developer.apple.com/documentation/pdfkit) - PDF rendering