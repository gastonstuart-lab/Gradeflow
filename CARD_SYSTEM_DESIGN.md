# Gradeflow Card System Design

## Vision
**Teacher command center with progressive disclosure.**

Rest state: compact, dense, beautiful
Hover state: card lifts, glows slightly, reveals one more layer
Tap state: card expands or docks open with full controls
Selected/focused state: one class becomes the main active workspace
Touch mode: same logic, triggered by tap/long-press instead of hover

## Target Platform Behavior

### Desktop (Mouse + Keyboard)
- **At rest**: Compact, no hover effects
- **Hover**: Card lifts subtly, accent glow, secondary info fades in, actions appear
- **Click card body**: Expands inline or selects/focuses for workspace mode
- **Click action**: Routes immediately
- **Keyboard**: Tab navigation, Enter to expand/select, arrow keys for focus

### Tablet/Touch (Surface Pro, iPad, Pen)
- **At rest**: Same compact layout
- **Tap**: Expands or selects (no hover state dependency)
- **Long-press**: Shows context menu of secondary actions
- **Pen tap**: Treated as click/tap depending on context
- **Portrait/narrow**: Single-column reflow, full-width expanded state

### Sizing & Touch Targets
- Minimum interactive target: 40×40 epx
- Preferred interactive target: 44×44 epx
- Padding between targets: 8–12 epx
- Cards: min-width 280 epx (compact), min-width 320 epx (tablet), full-width on mobile

---

## Class Card States & Contract

### 1. Collapsed State (Default)
**Display**:
- Class title (bold, 1 line, truncate)
- Subtitle: subject + period (secondary text, 1 line, truncate)
- Student count with icon (icon + text, 14 epx height)
- **One** status chip: icon + label (16 epx height, color-coded by health level)
- **One** primary action button (44 epx height min)

**Height**: 140 epx (compact), 148 epx (desktop)
**Layout**: Vertical stack, left-aligned
**Interaction**:
- Tap card body → Select/focus (or route to class detail)
- Hover card (desktop) → Lift, glow, fade in secondary layer
- Click primary action → Fire onTap for action
- Click secondary actions (if visible) → Disabled/not shown in collapsed

**No metrics, no detail, no secondary actions visible.**

### 2. Hover-Preview State (Desktop Only)
**Trigger**: MouseRegion enters, card not selected
**Display** (in addition to collapsed):
- Status chip remains prominent
- Subtle color shift on background (0.04 opacity increase)
- Secondary action buttons appear as small icon-only pills or labels below primary (opacity: 0.8)
- Card shadow lifts (elevation: 8 instead of 2)
- Accent glow under card body

**Interaction**:
- Hover out → Back to collapsed
- Click card body → Expand or select
- Click any action → Fire that action

**Duration**: 200 ms instant fade-in (no stagger)

### 3. Expanded State (Tap or Click)
**Trigger**: Tap card body or explicit expand call
**Display**:
- Everything from collapsed
- Status chip remains
- Full statusDetail text (may wrap to 2 lines)
- Metrics row: up to 3 metric chips (icon + label, small text)
- Recommended action section: label + detail (if present)
- **All** action buttons visible (primary + secondary), full-width or horizontally scrolled if needed
- "More" icon/button if additional menu exists

**Height**: 280–360 epx (variable based on content)
**Layout**: Vertical stack, full content visible
**Interaction**:
- Tap collapse/close button → Back to collapsed
- Tap any action → Fire that action
- Tap outside card (if modal) or press Escape → Back to collapsed

**Duration**: 300 ms smooth expand animation

### 4. Selected/Focused State
**Trigger**: User clicks "focus" or selects for workspace mode
**Display**:
- Card moves to right rail or docks into sidebar
- Card remains in main grid as visual indicator (border/outline + reduced opacity)
- Focused card in dock shows full details, live updates, and quick actions

**Styling**:
- Selected in grid: border (2 epx, accent color) + background tweak (0.02 alpha)
- Focused in dock: full card with elevated shadow, accessible focus ring

**Interaction**:
- Click another card → Switch focus
- Escape or "close focus" → Back to grid view

### 5. Touch-Only Mode (Mobile, Portrait)
**Trigger**: Viewport width < 600 epx or touch input detected
**Differences from desktop**:
- Hover/preview state disabled (no MouseRegion hover)
- Card takes full width when expanded
- Actions stack vertically or use horizontal scroll
- Tap to expand, tap close button to collapse
- Long-press on card → Context menu with secondary actions

---

## Card Anatomy

```
┌─ Card Container (LayoutBuilder, responsive width) ─────────────────┐
│                                                                      │
│  [Collapsed - 140–148 epx height]                                  │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ EEP 4 J1FG                            [title, bold, truncate] │  │
│  │ English • 2025-2026 Spring            [subtitle, secondary]   │  │
│  │                                                                │  │
│  │ 👥 22 students                        [icon + count]          │  │
│  │ ⚠️ Roster missing (8 epx gap)        [status chip]           │  │
│  │                                                                │  │
│  │ [Primary Action Button ──────────────────────────────────]   │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                              (on hover: lift + glow)                │
│                                                                      │
│  [Expanded - 280–360 epx height, triggered by tap/click]           │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ EEP 4 J1FG                                                    │  │
│  │ English • 2025-2026 Spring                                   │  │
│  │                                                                │  │
│  │ 👥 22 students                                                │  │
│  │ ⚠️ Roster missing                                             │  │
│  │ Review setup while timetable details are still missing.      │  │
│  │                                                                │  │
│  │ Metrics:                                                       │  │
│  │ [📊 Grades ──] [📅 Schedule ──] [✅ Setup Status ──]         │  │
│  │                                                                │  │
│  │ Recommended:                                                   │  │
│  │ Import roster                                                  │  │
│  │ Open classes and bring the roster in.                         │  │
│  │                                                                │  │
│  │ [Primary: Upload File] [Secondary: Open] [More ⋯]           │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Implementation Technical Details

### Flutter Primitives
- **MouseRegion**: Detect hover, show preview layer
- **AnimatedContainer**: Smooth shadow, scale (lift), background color transitions
- **AnimatedSize or AnimatedFractionallySizedBox**: Height expansion animation
- **AnimatedSwitcher or AnimatedOpacity**: Fade in/out secondary content

### Metrics/State Model
```dart
class DashboardClassCardState {
  bool isHovered = false;
  bool isExpanded = false;
  bool isSelected = false;
  bool isFocused = false;
  bool isTouch = false; // Platform detection
}
```

### Animation Timings
- Hover reveal: 200 ms, easeOut
- Expand: 300 ms, easeInOutCubic
- Lift (shadow): 150 ms, easeOut
- Color transitions: 200 ms, easeInOut

### Widget Test Contract
Each test validates one state and its transitions:
1. **Collapsed rendering**: title, subtitle, count, status chip, primary action only
2. **Hover preview** (if !isTouch): secondary actions fade in, no height change
3. **Expanded rendering**: all content visible, metrics shown, detail text visible
4. **Tap to expand**: collapsed → expanded animation completes, buttons clickable
5. **Tap to collapse**: expanded → collapsed, height shrinks, detail hidden
6. **Action firing**: primary/secondary taps call their onTap callbacks
7. **Touch mode**: hover state is never entered, long-press shows menu

---

## Migration Plan

### Step 1: Design Lock (This Document) ✅
### Step 2: Build Interactive Class Card
- Create new `InteractiveClassCard` widget with full state machine
- Base on `DashboardClassCard` logic but add MouseRegion, AnimatedContainer, expand/collapse
- Test each state independently
- Add snapshot/visual tests for each state

### Step 3: Update Test Contract
- Replace old `dashboard_class_card_test.dart` expectations
- Add tests for hover-preview (if desktop, else skip)
- Add tests for expand/collapse transitions
- Add tests for touch-mode detection

### Step 4: Polish Shell
- Apply same interactive pattern to quick-action cards, message cards
- Refine sidebar, command deck, spacing
- Add keyboard shortcuts

### Step 5: Surface Pro Specific
- Test on tablet breakpoints (480, 768 epx widths)
- Verify touch targets >= 44 epx
- Test portrait orientation reflow
- Test mixed input (pen + keyboard)

