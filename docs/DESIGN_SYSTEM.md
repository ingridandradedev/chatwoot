# Chatwoot Design System — Especificação Visual

## Visão Geral

O Chatwoot utiliza um design system baseado em **Tailwind CSS** com tokens customizados inspirados no **Radix UI Colors**. Suporta **dark mode** via classe `.dark`. A tipografia usa system fonts com fallback para Inter.

---

## Tipografia

### Fontes
- **Primária:** Inter (com fallback system-ui)
- **Display:** InterDisplay (para títulos de destaque)
- **Stack completo:** `-apple-system, system-ui, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Tahoma, Arial, sans-serif`

### Tamanhos
| Token | Valor |
|-------|-------|
| `text-xxs` | 0.625rem (10px) |
| `text-xs` | 0.75rem (12px) |
| `text-sm` | 0.875rem (14px) |
| `text-base` | 1rem (16px) |
| `text-lg` | 1.125rem (18px) |
| `text-xl` | 1.25rem (20px) |
| `text-2xl` | 1.5rem (24px) |

### Pesos
| Token | Valor |
|-------|-------|
| `font-normal` | 400 |
| `font-420` | 420 |
| `font-440` | 440 |
| `font-460` | 460 |
| `font-medium` | 500 |
| `font-520` | 520 |
| `font-semibold` | 600 |
| `font-620` | 620 |
| `font-bold` | 700 |

---

## Paleta de Cores

### Cor de Marca (Brand)
- **Brand Principal:** `#2781F6` (Azul)
- Uso: botões primários, links ativos, indicadores de seleção

### Escala Slate (Texto e UI)

#### Light Mode
| Step | RGB | Uso |
|------|-----|-----|
| slate-1 | `252 252 253` | Background profundo |
| slate-2 | `249 249 251` | Background sutil |
| slate-3 | `240 240 243` | Background de elementos |
| slate-4 | `232 232 236` | Background hover |
| slate-5 | `224 225 230` | Background ativo |
| slate-6 | `217 217 224` | Bordas sutis |
| slate-7 | `205 206 214` | Bordas padrão |
| slate-8 | `185 187 198` | Bordas fortes |
| slate-9 | `139 141 152` | Texto placeholder |
| slate-10 | `128 131 141` | Texto muted |
| slate-11 | `96 100 108` | Texto secundário |
| slate-12 | `28 32 36` | Texto principal |

#### Dark Mode
| Step | RGB | Uso |
|------|-----|-----|
| slate-1 | `17 17 19` | Background profundo |
| slate-2 | `24 25 27` | Background sutil |
| slate-3 | `33 34 37` | Background de elementos |
| slate-4 | `39 42 45` | Background hover |
| slate-5 | `46 49 53` | Background ativo |
| slate-6 | `54 58 63` | Bordas sutis |
| slate-7 | `67 72 78` | Bordas padrão |
| slate-8 | `90 97 105` | Bordas fortes |
| slate-9 | `105 110 119` | Texto placeholder |
| slate-10 | `119 123 132` | Texto muted |
| slate-11 | `176 180 186` | Texto secundário |
| slate-12 | `237 238 240` | Texto principal |

### Escala Blue (Informação/Brand)
| Step | Light Mode | Dark Mode |
|------|-----------|-----------|
| blue-9 (principal) | `39 129 246` | `39 129 246` |
| blue-11 (texto) | `8 109 224` | `126 182 255` |
| blue-12 (heading) | `11 50 101` | `205 227 255` |

### Escala Ruby (Erro/Perigo)
| Step | Light Mode | Dark Mode |
|------|-----------|-----------|
| ruby-9 (principal) | `229 70 102` | `229 70 102` |
| ruby-11 (texto) | `202 36 77` | `255 148 157` |

### Escala Amber (Aviso/Atenção)
| Step | Light Mode | Dark Mode |
|------|-----------|-----------|
| amber-9 (principal) | `255 197 61` | `255 197 61` |
| amber-11 (texto) | `171 100 0` | `255 202 22` |

### Escala Teal (Sucesso)
| Step | Light Mode | Dark Mode |
|------|-----------|-----------|
| teal-9 (principal) | `18 165 148` | `18 165 148` |
| teal-11 (texto) | `0 133 115` | `11 216 182` |

### Escala Iris (Destaques/CTA)
| Step | Light Mode | Dark Mode |
|------|-----------|-----------|
| iris-9 (principal) | `91 91 214` | `91 91 214` |
| iris-11 (texto) | `87 83 198` | `158 177 255` |

### Escala Violet (Complementar)
| Step | Light Mode | Dark Mode |
|------|-----------|-----------|
| violet-9 (principal) | `110 86 207` | `110 86 207` |
| violet-11 (texto) | `101 85 183` | `169 153 236` |

---

## Superfícies e Backgrounds

### Light Mode
| Token | RGB | Hex aprox. | Uso |
|-------|-----|-----------|-----|
| `background` | `247 247 247` | `#F7F7F7` | Background da aplicação |
| `surface-1` | `254 254 254` | `#FEFEFE` | Cards, painéis |
| `surface-2` | `255 255 255` | `#FFFFFF` | Inputs, modais |
| `surface-active` | `255 255 255` | `#FFFFFF` | Estado ativo |

### Dark Mode
| Token | RGB | Hex aprox. | Uso |
|-------|-----|-----------|-----|
| `background` | `28 29 32` | `#1C1D20` | Background da aplicação |
| `surface-1` | `20 21 23` | `#141517` | Cards, painéis |
| `surface-2` | `22 23 26` | `#16171A` | Inputs, modais |
| `surface-active` | `53 57 66` | `#353942` | Estado ativo |

---

## Bordas

| Token | Light Mode | Dark Mode | Uso |
|-------|-----------|-----------|-----|
| `border-weak` | `234 234 234` | `31 31 37` | Bordas leves (cards, divisores) |
| `border-strong` | `226 227 231` | `46 45 50` | Bordas de contraste (headers) |

---

## Ícones

- **Biblioteca:** Lucide Icons
- **Prefixo Tailwind:** `i-lucide-{nome}`
- **Ícones customizados:** coleção `woot` via `i-woot-{nome}`
- **Outras coleções disponíveis:** `ri`, `ph`, `material-symbols`, `teenyicons`, `fluent`, `logos`

### Ícones mais usados no CRM
| Componente | Ícone |
|-----------|-------|
| CRM (sidebar) | `i-lucide-kanban` |
| Adicionar | `i-lucide-plus` |
| Editar | `i-lucide-pencil` |
| Deletar | `i-lucide-trash-2` |
| Configurações | `i-lucide-settings` |
| Contatos | `i-lucide-users` |
| Empresas | `i-lucide-building-2` |
| Relatórios | `i-lucide-chart-spline` |

---

## Componentes Base

### Botões
- **Componente:** `NextButton` (`components-next/button/Button.vue`)
- **Variantes:** default (brand), `faded`, `slate`
- **Tamanhos:** `sm`, default, `lg`
- **Cores de botão primário:**
  - Background: `bg-n-brand` (`#2781F6`)
  - Texto: `text-white`
  - Hover: `hover:bg-n-brand-dark`

### Modais
- **Componente:** `woot-modal` (global)
- **Header:** `woot-modal-header`
- **Backdrop light:** `rgba(0, 0, 0, 0.4)`
- **Backdrop dark:** `rgba(0, 0, 0, 0.6)`

### Cards
- **Background:** `bg-white dark:bg-n-slate-3`
- **Borda:** `border border-n-weak`
- **Sombra:** `shadow-sm`
- **Radius:** `rounded-lg` (0.5rem)

### Inputs
- **Background:** `bg-n-alpha-black2`
- **Borda:** `border border-n-weak`
- **Texto:** `text-n-slate-12`
- **Placeholder:** `text-n-slate-10`
- **Focus:** `focus:outline-none focus:border-n-brand`
- **Altura:** `h-10` (2.5rem)
- **Radius:** `rounded-lg`

---

## Breakpoints

| Token | Largura |
|-------|---------|
| `xs` | 480px |
| `sm` | 640px |
| `md` | 768px |
| `lg` | 1024px |
| `xl` | 1280px |
| `2xl` | 1536px |
| `3xl` | 1900px |

---

## Dark Mode

- Implementação via classe `.dark` no `<html>` ou container raiz
- Ativação: toggle manual pelo usuário
- Todas as cores do design system têm variantes dark automáticas via CSS variables

---

## Animações

| Nome | Duração | Uso |
|------|---------|-----|
| `wiggle` | 0.5s | Feedback de erro (shake) |
| `fade-in-up` | 0.3s | Entrada de elementos |
| `loader-pulse` | 1.5s (loop) | Loading states |
| `card-select` | 0.25s | Seleção de cards |
| `shake` | 0.3s (2x) | Validação de formulário |

---

## Espaçamento e Layout

- Sistema padrão do Tailwind (4px base grid)
- Padding padrão de páginas: `px-6 py-4`
- Gap padrão entre elementos: `gap-2` (8px) a `gap-4` (16px)
- Border radius padrão: `rounded-lg` (8px)

---

## Guia de Aplicação para Marketing

### Cores para usar em materiais
- **Principal/CTA:** `#2781F6` (Blue-9)
- **Background claro:** `#F7F7F7`
- **Background escuro:** `#1C1D20`
- **Texto principal claro:** `#1C2024` (slate-12 light)
- **Texto principal escuro:** `#EDEEF0` (slate-12 dark)
- **Sucesso/Online:** `#12A594` (teal-9)
- **Erro/Urgente:** `#E5466A` (ruby-9)
- **Alerta:** `#FFC53D` (amber-9)

### Tom visual
- Clean, minimalista, profissional
- Muito espaço em branco no light mode
- Alto contraste de texto em ambos os modos
- Cantos arredondados (8px padrão)
- Sombras mínimas (shadow-sm)
- Interface focada em produtividade/dados
