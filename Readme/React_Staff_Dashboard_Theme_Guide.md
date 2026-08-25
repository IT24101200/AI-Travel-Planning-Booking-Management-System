# React Staff Dashboard — Official Theme
**Applies to:** All 4 React components (Customer Directory, Tour Catalog, Hotel/Transport Management, Booking Approval)
**Rule:** Everyone imports these exact values. Nobody picks their own colors/fonts.

---

## 1. Color Palette (final — use these exact hex codes)

| Role | Used for | Hex code |
|---|---|---|
| **Primary** | Main buttons, links, active nav item | `#2563EB` (blue) |
| **Primary — hover** | Button/link hover state | `#1D4ED8` |
| **Background** | Page background | `#F8F9FB` |
| **Surface** | Cards, table backgrounds, modals | `#FFFFFF` |
| **Text — main** | Body text, headings | `#1A1A1A` |
| **Text — muted** | Secondary text, timestamps, labels | `#6B7280` |
| **Border/divider** | Table lines, card outlines, input borders | `#E5E7EB` |
| **Success** | Confirmed, Approved, Paid, Active | `#16A34A` |
| **Success — background** | Badge background for success | `#DCFCE7` |
| **Warning** | Pending, AwaitingApproval, RevisionRequested | `#D97706` |
| **Warning — background** | Badge background for warning | `#FEF3C7` |
| **Danger** | Rejected, Failed, Cancelled, Inactive, delete actions | `#DC2626` |
| **Danger — background** | Badge background for danger | `#FEE2E2` |

**Why blue as primary:** neutral, professional, works for a travel/booking product without implying "buy now" urgency the way orange/red would. It's a common, safe choice for internal staff tools — nobody needs to personally like it, it just needs to be consistent everywhere.

---

## 2. Typography (final)

| Role | Font | Weight | Size |
|---|---|---|---|
| Page title | **Inter** | Bold (700) | `24px` |
| Section/table headers | Inter | Semi-bold (600) | `16px` |
| Body / table text | Inter | Regular (400) | `14px` |
| Small labels/timestamps | Inter | Regular (400) | `12px` |

**One font only: Inter.** Free (Google Fonts), clean, extremely common for dashboards (used by Linear, Vercel, GitHub). Import once, use everywhere — no second font needed.

```html
<!-- Add this once, in index.html -->
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
```

---

## 3. Status Badges (final spec)

Every status across every component uses this exact style:

- **Shape:** pill, `border-radius: 9999px`
- **Padding:** `4px 12px`
- **Font:** `12px`, weight `600`, sentence case (e.g. "Confirmed" not "CONFIRMED")

| Status text | Badge text color | Badge background |
|---|---|---|
| Confirmed / Approved / Paid / Active | `#16A34A` | `#DCFCE7` |
| Pending / AwaitingApproval / RevisionRequested | `#D97706` | `#FEF3C7` |
| Rejected / Failed / Cancelled / Inactive | `#DC2626` | `#FEE2E2` |

---

## 4. Buttons (final spec)

| Type | Background | Text color | Border |
|---|---|---|---|
| Primary (Save, Approve, Add) | `#2563EB` (hover: `#1D4ED8`) | `#FFFFFF` | none |
| Secondary (Cancel, Back) | `#FFFFFF` | `#1A1A1A` | `1px solid #E5E7EB` |
| Destructive (Delete, Reject) | `#FFFFFF` | `#DC2626` | `1px solid #DC2626` |

All buttons: `border-radius: 6px`, `padding: 8px 16px`, `font-size: 14px`, `font-weight: 600`.

---

## 5. Layout & Spacing (final)

- Page padding: `24px`
- Card padding: `20px`
- Card style: `background: #FFFFFF`, `border: 1px solid #E5E7EB`, `border-radius: 8px`
- Table row height: `48px`
- Table header: background `#F8F9FB`, text `#6B7280`, `12px`, uppercase, weight `600`
- Table row hover: `#F8F9FB`

---

## 6. Copy-paste CSS variables (put this in one shared file, everyone imports it)

```css
:root {
  --color-primary: #2563EB;
  --color-primary-hover: #1D4ED8;
  --color-background: #F8F9FB;
  --color-surface: #FFFFFF;
  --color-text: #1A1A1A;
  --color-text-muted: #6B7280;
  --color-border: #E5E7EB;

  --color-success: #16A34A;
  --color-success-bg: #DCFCE7;
  --color-warning: #D97706;
  --color-warning-bg: #FEF3C7;
  --color-danger: #DC2626;
  --color-danger-bg: #FEE2E2;

  --font-family: 'Inter', sans-serif;
  --radius-sm: 6px;
  --radius-md: 8px;
}
```

**File location:** `frontend-react/src/components/theme.css` (shared folder, per your repo structure — everyone imports this file; nobody hardcodes hex values in their own page).

---

## 7. Rule for all 4 teammates

Every table, badge, button, and card across all 4 React pages must use these exact values — through the CSS variables above, not retyped hex codes. If a page seems to need a color not in this list, stop and ask the team before adding one — that's how the "one red, one green" problem happens.
