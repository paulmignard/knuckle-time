# Knuckle Time — Brutalist UI Spec

Hand this document to Claude Code to implement the new brutalist design for the Knuckle Time iOS app.

---

## Design Philosophy

**Brutalist + Skeuomorphic Contrast**

The UI is raw, industrial, and utilitarian — monospace typography, sharp corners, exposed grid lines, uppercase labels. But the timer display is a warm, glowing, retro LED/CRT element that provides emotional contrast. The timer is the human element in a machine interface.

Think: military HUD meets vintage electronics.

---

## Color Palette

### Primary Colors

| Name | Hex | Usage |
|------|-----|-------|
| Green | `#30d158` | Primary accent, active states, timer glow, borders |
| Red | `#ff453a` | Stop button, danger, delete |

### Backgrounds

| Name | Hex | Usage |
|------|-----|-------|
| Black | `#000000` | Main background |
| Dark Gray | `#222222` | Borders, separators |
| Mid Gray | `#333333` | Secondary borders |

### Text

| Name | Hex | Usage |
|------|-----|-------|
| White | `#ffffff` | Primary text, headings |
| Light Gray | `#666666` | Secondary text, labels |
| Dark Gray | `#444444` | Tertiary text, hints |

### SwiftUI Color Extension

```swift
extension Color {
    static let knuckleGreen = Color(hex: "30d158")
    static let knuckleRed = Color(hex: "ff453a")
    static let knuckleBg = Color(hex: "000000")
    static let knuckleBorder = Color(hex: "222222")
    static let knuckleTextPrimary = Color.white
    static let knuckleTextSecondary = Color(hex: "666666")
    static let knuckleTextTertiary = Color(hex: "444444")
}
```

---

## Typography

### Font Stack

Use **monospace only** throughout the app:

```swift
// Primary font
.font(.system(.body, design: .monospaced))

// For specific sizes
.font(.system(size: 11, weight: .regular, design: .monospaced))
```

### Type Scale

| Element | Size | Weight | Letter Spacing | Case |
|---------|------|--------|----------------|------|
| Page header (e.g., "TIMER") | 48pt | Bold | -2pt | UPPERCASE |
| Section label (e.g., "KNUCKLE//DASHBOARD") | 11pt | Regular | 4pt | UPPERCASE |
| Client name | 24pt | Bold | 2pt | UPPERCASE |
| Field label (e.g., "CLIENT") | 10pt | Regular | 2pt | UPPERCASE |
| Stat value | 32pt | Bold | 0 | Normal |
| Stat label | 11pt | Regular | 2pt | UPPERCASE |
| Button text | 14pt | Bold | 4pt | UPPERCASE |
| Timer display | 72pt | Regular | 0 | Normal |
| Geofence status | 11pt | Regular | 1pt | UPPERCASE |
| Coordinates | 10pt | Regular | 1pt | UPPERCASE |
| Timestamp | 10pt | Regular | 1pt | UPPERCASE |

### Key Typography Rules

1. **Everything is uppercase** except timer digits
2. **Letter spacing is generous** — most labels have 1-4pt tracking
3. **Use tabular/monospaced figures** for all numbers: `.monospacedDigit()`
4. **No rounded fonts** — system monospace only

---

## Layout Structure

### Screen Hierarchy

```
┌─────────────────────────────────────┐
│ Status Bar                    06:13 │
├─────────────────────────────────────┤
│ KNUCKLE//DASHBOARD                  │
│ TIMER                               │ ← 48pt bold
├─────────────────────────────────────┤
│ ■ GEOFENCE: ACME HQ       [TAP] │
├─────────────────────────────────────┤
│ LAT: 37.4138°N      LON: 79.1422°W  │ ← Only when in geofence
├─────────────────────────────────────┤
│ CLIENT                              │
│ ACME                            │
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │                                 │ │
│ │        00:00:09                 │ │ ← Skeuomorphic timer
│ │                                 │ │
│ └─────────────────────────────────┘ │
├─────────────────────────────────────┤
│              STARTED: 06:13:00      │
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │          ■ STOP                 │ │ ← Red when running
│ └─────────────────────────────────┘ │
├─────────────────────────────────────┤
│ STATISTICS                          │
│ ▸ TODAY                      0.0 HRS│
│   WEEK                       0.0 HRS│
│   MONTH                      4.4 HRS│
├─────────────────────────────────────┤
│ [TMR]     │ [ENT]      │ [SET]      │ ← Tab bar
│  TIMER    │  ENTRIES   │  SETTINGS  │
└─────────────────────────────────────┘
```

### Spacing

- Horizontal padding: 16pt
- Section dividers: 2px solid white (major) or 1px solid #222 (minor)
- Vertical rhythm: 12-20pt between sections

---

## Component Specs

### 1. Header Section

```swift
VStack(alignment: .leading, spacing: 8) {
    Text("KNUCKLE//DASHBOARD")
        .font(.system(size: 11, design: .monospaced))
        .tracking(4)
        .foregroundColor(.knuckleTextSecondary)
    
    Text("TIMER")
        .font(.system(size: 48, weight: .bold, design: .monospaced))
        .tracking(-2)
        .foregroundColor(.white)
}
.padding(.vertical, 16)
.border(width: 2, edges: [.bottom], color: .white)
```

### 2. Geofence Indicator

**States:**
- **Not in geofence:** Gray square, "GEOFENCE: NONE"
- **In geofence:** Green glowing square, "GEOFENCE: [NAME]", pulsing animation

```swift
HStack(spacing: 12) {
    // Status indicator
    Rectangle()
        .fill(inGeofence ? Color.knuckleGreen : Color.knuckleTextSecondary)
        .frame(width: 8, height: 8)
        .shadow(color: inGeofence ? .knuckleGreen.opacity(0.8) : .clear, radius: 8)
    
    Text(inGeofence ? "GEOFENCE: \(geofenceName)" : "GEOFENCE: NONE")
        .font(.system(size: 11, design: .monospaced))
        .tracking(1)
        .foregroundColor(inGeofence ? .knuckleGreen : .knuckleTextSecondary)
    
    Spacer()
}
.padding(.vertical, 12)
.border(width: 1, edges: [.bottom], color: .knuckleBorder)
```

### 3. Coordinates Display (only when in geofence)

```swift
if inGeofence {
    HStack {
        Text("LAT: \(latitude, specifier: "%.4f")°N")
        Spacer()
        Text("LON: \(longitude, specifier: "%.4f")°W")
    }
    .font(.system(size: 10, design: .monospaced))
    .tracking(1)
    .foregroundColor(.knuckleTextTertiary)
    .monospacedDigit()
    .padding(.vertical, 8)
    .border(width: 1, edges: [.bottom], color: Color(hex: "222222"))
}
```

### 4. Skeuomorphic Timer Display

This is the hero element. It should feel like a vintage LED display.

**Container:**
- Border: 3px solid green
- Inner padding: 4px
- Background: Black

**Display area:**
- Background: Linear gradient from `#0a1a0f` → `#0d1f12` → `#0a1a0f`
- Scanline overlay: Repeating horizontal lines (2px transparent, 2px black at 20% opacity)
- Inner glow when running: Radial gradient of green at 20% opacity

**Digits:**
- Font: 72pt monospace, regular weight
- Color: `#30d158`
- Text shadow (glow effect):
  - 0 0 10px green at 90% opacity
  - 0 0 20px green at 50% opacity  
  - 0 0 40px green at 30% opacity
- Colons blink when running (1 second interval, step animation)

```swift
struct RetroTimerDisplay: View {
    let time: String // "00:00:09"
    let isRunning: Bool
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(hex: "0a1a0f"),
                    Color(hex: "0d1f12"),
                    Color(hex: "0a1a0f")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Scanlines overlay
            ScanlinesView()
            
            // Glow effect when running
            if isRunning {
                RadialGradient(
                    colors: [
                        Color.knuckleGreen.opacity(0.2),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 150
                )
                .animation(.easeInOut(duration: 2).repeatForever(), value: isRunning)
            }
            
            // Timer text
            Text(time)
                .font(.system(size: 72, weight: .regular, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(.knuckleGreen)
                .shadow(color: .knuckleGreen.opacity(0.9), radius: 10)
                .shadow(color: .knuckleGreen.opacity(0.5), radius: 20)
                .shadow(color: .knuckleGreen.opacity(0.3), radius: 40)
        }
        .padding(32)
        .background(Color.black)
        .border(Color.knuckleGreen, width: 3)
        .padding(4)
        .background(Color.black)
    }
}

struct ScanlinesView: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                for y in stride(from: 0, to: geo.size.height, by: 4) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
            }
            .stroke(Color.black.opacity(0.2), lineWidth: 2)
        }
    }
}
```

### 5. Stop/Start Button

**Running state:**
- Background: `#ff453a` (red)
- Text: "■ STOP"
- No border radius (sharp corners!)

**Stopped state:**
- Background: `#30d158` (green)
- Text: "▶ START"

```swift
Button(action: toggleTimer) {
    Text(isRunning ? "■ STOP" : "▶ START")
        .font(.system(size: 14, weight: .bold, design: .monospaced))
        .tracking(4)
        .foregroundColor(.black)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(isRunning ? Color.knuckleRed : Color.knuckleGreen)
}
.buttonStyle(.plain)
```

### 6. Statistics List

No cards! Just raw data rows.

```swift
VStack(spacing: 0) {
    Text("STATISTICS")
        .font(.system(size: 10, design: .monospaced))
        .tracking(2)
        .foregroundColor(.knuckleTextSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 16)
    
    ForEach(stats) { stat in
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 4) {
                if stat.isActive {
                    Text("▸")
                }
                Text(stat.label)
            }
            .font(.system(size: 11, design: .monospaced))
            .tracking(2)
            .foregroundColor(stat.isActive ? .knuckleGreen : .knuckleTextSecondary)
            
            Spacer()
            
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(stat.value)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(stat.isActive ? .knuckleGreen : .white)
                
                Text("HRS")
                    .font(.system(size: 10, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(.knuckleTextSecondary)
            }
        }
        .padding(.vertical, 16)
        .border(width: 1, edges: [.bottom], color: .knuckleBorder)
    }
}
.padding(.top, 20)
.border(width: 2, edges: [.top], color: .white)
```

### 7. Tab Bar

Industrial segmented control, not iOS standard.

```swift
HStack(spacing: 0) {
    ForEach(tabs) { tab in
        Button(action: { selectedTab = tab }) {
            VStack(spacing: 4) {
                Text("[\(tab.shortLabel)]")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2)
                
                Text(tab.fullLabel)
                    .font(.system(size: 9, design: .monospaced))
                    .tracking(1)
            }
            .foregroundColor(selectedTab == tab ? .black : .knuckleTextSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.bottom, 16) // Safe area
            .background(selectedTab == tab ? Color.knuckleGreen : Color.clear)
        }
        
        if tab != tabs.last {
            Rectangle()
                .fill(Color.knuckleBorder)
                .frame(width: 1)
        }
    }
}
.background(Color.black)
.border(width: 2, edges: [.top], color: .knuckleGreen)
```

**Tab data:**

| ID | Short | Full |
|----|-------|------|
| timer | TMR | TIMER |
| entries | ENT | ENTRIES |
| settings | SET | SETTINGS |

---

## Geofence Map Background

When the user is inside a geofence, show a satellite map as the background.

### Implementation

1. **Get static map image** from MapKit or a static map API using the geofence center coordinates
2. **Apply filters:**
   - Grayscale: 100%
   - Contrast: 1.2
   - Brightness: 0.8
3. **Set opacity:** 25%
4. **Add overlays:**
   - Dark gradient: `rgba(0, 10, 5, 0.4)` at top → `rgba(0, 0, 0, 0.7)` at bottom
   - Vignette: Radial gradient, transparent center → black edges at 60% opacity

### SwiftUI Implementation

```swift
struct GeofenceBackgroundView: View {
    let coordinate: CLLocationCoordinate2D
    let isActive: Bool
    
    var body: some View {
        if isActive {
            ZStack {
                // Satellite map snapshot
                MapSnapshotView(coordinate: coordinate)
                    .saturation(0) // Grayscale
                    .contrast(1.2)
                    .brightness(-0.2)
                    .opacity(0.25)
                
                // Green-tinted dark overlay
                LinearGradient(
                    colors: [
                        Color(red: 0, green: 0.04, blue: 0.02).opacity(0.4),
                        Color.black.opacity(0.7)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Vignette
                RadialGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.6)
                    ],
                    center: .center,
                    startRadius: 100,
                    endRadius: 400
                )
            }
        }
    }
}

struct MapSnapshotView: View {
    let coordinate: CLLocationCoordinate2D
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
        }
        .onAppear {
            generateSnapshot()
        }
    }
    
    func generateSnapshot() {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 500,
            longitudinalMeters: 500
        )
        options.mapType = .satellite
        options.size = CGSize(width: 600, height: 1200)
        
        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start { snapshot, error in
            if let snapshot = snapshot {
                self.image = snapshot.image
            }
        }
    }
}
```

### Grid Overlay

Always visible, but more prominent when satellite is showing:

```swift
struct GridOverlayView: View {
    let opacity: Double // 0.03 normally, 0.06 when in geofence
    
    var body: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 20
            
            // Vertical lines
            for x in stride(from: 0, to: size.width, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.knuckleGreen.opacity(opacity)), lineWidth: 1)
            }
            
            // Horizontal lines
            for y in stride(from: 0, to: size.height, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.knuckleGreen.opacity(opacity)), lineWidth: 1)
            }
        }
    }
}
```

### Corner Markers (Targeting Reticle)

Always show top corners. Show bottom corners + center crosshair only when in geofence.

```swift
struct CornerMarkersView: View {
    let inGeofence: Bool
    
    var body: some View {
        GeometryReader { geo in
            // Top-left
            CornerBracket(edges: [.top, .leading])
                .position(x: 28, y: 72)
            
            // Top-right
            CornerBracket(edges: [.top, .trailing])
                .position(x: geo.size.width - 28, y: 72)
            
            if inGeofence {
                // Bottom-left
                CornerBracket(edges: [.bottom, .leading])
                    .position(x: 28, y: geo.size.height - 112)
                    .opacity(0.6)
                
                // Bottom-right
                CornerBracket(edges: [.bottom, .trailing])
                    .position(x: geo.size.width - 28, y: geo.size.height - 112)
                    .opacity(0.6)
                
                // Center crosshair
                CrosshairView()
                    .frame(width: 40, height: 40)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.45)
                    .opacity(0.3)
            }
        }
    }
}

struct CornerBracket: View {
    let edges: [Edge]
    
    var body: some View {
        ZStack {
            if edges.contains(.top) {
                Rectangle()
                    .fill(Color.knuckleGreen)
                    .frame(width: 24, height: 2)
                    .offset(y: -11)
            }
            if edges.contains(.bottom) {
                Rectangle()
                    .fill(Color.knuckleGreen)
                    .frame(width: 24, height: 2)
                    .offset(y: 11)
            }
            if edges.contains(.leading) {
                Rectangle()
                    .fill(Color.knuckleGreen)
                    .frame(width: 2, height: 24)
                    .offset(x: -11)
            }
            if edges.contains(.trailing) {
                Rectangle()
                    .fill(Color.knuckleGreen)
                    .frame(width: 2, height: 24)
                    .offset(x: 11)
            }
        }
        .frame(width: 24, height: 24)
    }
}

struct CrosshairView: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.knuckleGreen)
                .frame(height: 1)
            Rectangle()
                .fill(Color.knuckleGreen)
                .frame(width: 1)
        }
    }
}
```

---

## Animations

### 1. Colon Blink (Timer)

When timer is running, colons blink every 1 second.

```swift
@State private var colonVisible = true

// In timer view
Text(":")
    .opacity(colonVisible ? 1 : 0.3)
    .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
        if isRunning {
            colonVisible.toggle()
        }
    }
```

### 2. Glow Pulse (Timer)

Subtle breathing animation on the timer glow when running.

```swift
@State private var glowIntensity: Double = 0.6

RadialGradient(...)
    .opacity(glowIntensity)
    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: glowIntensity)
    .onAppear {
        glowIntensity = 1.0
    }
```

### 3. Geofence Indicator Pulse

When in geofence, the green indicator square pulses.

```swift
@State private var indicatorScale: CGFloat = 1.0

Rectangle()
    .fill(Color.knuckleGreen)
    .frame(width: 8, height: 8)
    .scaleEffect(indicatorScale)
    .shadow(color: .knuckleGreen, radius: 8)
    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: indicatorScale)
    .onAppear {
        indicatorScale = 1.2
    }
```

---

## Status Bar Enhancements

When in geofence, add a "◉ LOCKED" indicator that pulses:

```swift
HStack {
    if inGeofence {
        Text("◉ LOCKED")
            .font(.system(size: 10, design: .monospaced))
            .tracking(1)
            .foregroundColor(.knuckleGreen)
            .opacity(lockedOpacity)
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: lockedOpacity)
    }
    // ... rest of status bar
}
```

---

## Migration Checklist

### Remove
- [ ] All border radius (use sharp corners everywhere except timer)
- [ ] System fonts (replace with monospace)
- [ ] Card backgrounds (use borders/dividers instead)
- [ ] Rounded buttons
- [ ] Lowercase text in labels
- [ ] Emoji icons in tab bar

### Add
- [ ] Monospace font throughout
- [ ] Uppercase labels with letter spacing
- [ ] Green accent borders
- [ ] Grid overlay
- [ ] Corner markers
- [ ] Satellite map background for geofence
- [ ] Scanline effect on timer
- [ ] Glow effects on timer
- [ ] Colon blink animation
- [ ] Coordinates display
- [ ] "LOCKED" status indicator

### Keep
- [ ] Skeuomorphic timer aesthetic (enhance it!)
- [ ] Green/red color scheme
- [ ] Overall layout structure
- [ ] Geofence detection logic
- [ ] Timer functionality

---

## Files to Modify

1. **Colors.swift** — Add new color definitions
2. **TimerView.swift** — Implement brutalist layout + enhanced timer
3. **Components/RetroTimerDisplay.swift** — New component for the LED timer
4. **Components/GeofenceBackground.swift** — Satellite map background
5. **Components/GridOverlay.swift** — Grid pattern overlay
6. **Components/CornerMarkers.swift** — Targeting reticle corners
7. **TabBar.swift** — Industrial segmented control
8. **StatisticsView.swift** — Raw data list layout

---

## Reference

The JSX mockup is available at: `knuckle-brutal-satellite.jsx`

This is a React/web implementation that demonstrates all the visual elements. Use it as a visual reference for the iOS implementation.

---

*Spec created: February 2026*
*Design: Brutalist + Skeuomorphic*
*App: Knuckle Time*
