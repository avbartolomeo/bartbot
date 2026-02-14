# five4.com.ar — Contexto de Migración (WordPress → sitio estático) y decisiones

**Última actualización:** 2026-02-13 (UTC)

## Registro de decisiones (living log)

> Formato: **fecha (UTC)** — decisión — motivo breve — impacto / próximos pasos

- **2026-02-13** — Priorizar **migración a sitio estático** sobre actualizar WordPress — menor mantenimiento y superficie de ataque — definir stack (Astro/hosting) y preparar redirects/SEO.
- **2026-02-13** — Sitio final en **4 idiomas (ES/EN/IT/PT)** con i18n por rutas (`/`, `/en/`, `/it/`, `/pt/`) — SEO + claridad — implementar `hreflang` + selector de idioma.
- **2026-02-13** — Workflow: **archivos en Git + GitHub Actions** — autonomía y trazabilidad — elegir hosting compatible (Cloudflare Pages/Netlify/Vercel).
- **2026-02-13** — Blog automatizado: **publicación cada 3 días vía PR con aprobación** — control editorial y calidad — definir pipeline (generación ES + traducciones EN/IT/PT) y calendario.
- **2026-02-13** — Sitio objetivo enfocado en consultoría: **Gobierno de datos, analítica, ciencia de datos e IA basada en datos** + madurez data-driven — claridad B2B y SEO — diseñar service pages + casos + bios + FAQs.
- **2026-02-13** — Seguridad: **SSH por llave**, **root SSH deshabilitado**, **UFW deny-by-default**, **Fail2ban más agresivo** — reducir riesgo inmediato — mantener SSH en puerto 22.
- **2026-02-14** — Mitigación web (Nivel 1): **cert válido Let’s Encrypt + headers + bloqueo readme.html + Basic Auth en /wp-login.php y /wp-admin** — bajar riesgo mientras no migramos — planear migración a estático.
- **2026-02-13** — Operación: crear usuario de mantenimiento **`openclaw`** con sudo — permitir mantenimiento continuo sin root SSH — validar accesos y luego migrar.

## 0) Situación inicial / diagnóstico
- Hosting actual: Droplet DigitalOcean, IP **107.170.172.96**.
- OS: **Ubuntu 14.04.6 (EOL)**, stack viejo (Apache 2.4.7, PHP 5.5.x).
- Sitio: WordPress (se detectó WP **4.5.32**), con estructura tipo “one-page” con anclas.
- Problemas iniciales:
  - HTTP devolvía **500** (WordPress sin conexión a DB).
  - HTTPS/443 no estaba levantado; luego se levantó con certificado **self-signed** (advertencia de navegador).
  - Se observaron eventos de **OOM** (kernel mató `mysqld`).

## 1) Objetivo del proyecto
- Dejar de depender de WordPress/MySQL (bajar mantenimiento y superficie de ataque).
- Migrar **estilo/estructura** a un sitio moderno; **contenido** se reescribe luego.
- Sitio final en **4 idiomas**: **ES / EN / IT / PT**.
- Flujo de trabajo: **archivos en Git** + **GitHub Actions** para publicar.

## 2) Decisiones tomadas
### 2.1 Seguridad / operación del servidor actual (contención)
- Se aplicó hardening en SSH:
  - `PasswordAuthentication no` (SSH solo por llave).
  - `PermitRootLogin no` (root por SSH deshabilitado).
  - `AllowUsers administrator openclaw`.
  - `X11Forwarding no`.
- Firewall:
  - UFW activo, **default deny incoming**.
  - Puertos permitidos: **22, 80, 443**.
  - Logging UFW: **low**.
- Fail2ban:
  - Se decidió mantener SSH en **puerto 22**.
  - Ajuste más agresivo para `sshd`: `maxretry=3`, `findtime=600`, `bantime=86400`.
- Usuario de mantenimiento:
  - Se creó usuario **`openclaw`** con acceso por llave y sudo (para mantenimiento continuo sin root SSH).

### 2.2 Estabilidad
- Se creó **swapfile de 2GB** (`/swapfile`) y persistencia en `/etc/fstab`.
- `vm.swappiness=10`.

### 2.3 Dirección de migración
- Se prioriza migración a **sitio estático** (low-maintenance, performance, seguridad) sobre “actualizar WordPress”.
- Multi-idioma: se recomienda i18n por rutas:
  - Español (default): `/`
  - Inglés: `/en/`
  - Italiano: `/it/`
  - Portugués: `/pt/`

### 2.4 Hosting objetivo (pendiente de elección)
Se evaluaron opciones que encajan con Git + CI:
- **Cloudflare Pages** (recomendado)
- Netlify
- Vercel

**Pendiente:** elegir proveedor (Cloudflare Pages vs Netlify, etc.) y confirmar dónde está el DNS actualmente (Cloudflare vs DO vs otro).

## 3) Información de estructura/SEO a preservar
- URLs a preservar por SEO/backlinks (al menos):
  - `/` (home)
  - `/blog/` (si se mantiene)
  - `/feature/*` (detectadas:
    - `/feature/app-web-mobile/`
    - `/feature/intranet-redes-sociales/`
    - `/feature/innovacion-aplicada/`)
- Plan SEO mínimo:
  - Redirections 301 de URLs viejas a nuevas (si cambian).
  - `hreflang` para ES/EN/IT/PT.
  - sitemap.xml + robots.txt.
  - canonical correcto.

## 4) Propuesta de estilo (direcciones visuales)
Tres opciones para elegir (todas modernas, rápidas de implementar):
- **A) Tech sobrio / B2B premium** (Space Grotesk + Inter, dark/neutral, acento azul)
- **B) Claro editorial / confianza** (Manrope/IBM Plex + Inter, fondos claros, acento azul/violeta)
- **C) Innovación con gradientes discretos** (Sora + Inter, gradientes solo en highlights)

## 5) Wireframe / Sitemap sugerido
### Home (secciones)
1. Hero (valor + 2 CTAs)
2. Logos clientes
3. Servicios (cards)
4. Metodología
5. Casos/resultados
6. Diferenciadores/testimonios
7. Blog (opcional)
8. Contacto

### Páginas
- Home
- Servicios (hub)
- Páginas de servicio (idealmente reusando `/feature/.../`)
- Empresa
- Contacto
- Blog (opcional; decidir si multilenguaje o solo ES)

## 6) Plan de implementación (rápido, low-risk)
- Semana 1:
  - Auditoría de URLs actuales + redirects.
  - Definir estilo (A/B/C) y sistema de componentes.
  - Montar repo + estructura i18n + templates.
- Semana 2:
  - Implementar páginas mínimas en 4 idiomas (placeholder si hace falta).
  - SEO técnico + performance.
  - Deploy (Pages/Netlify) + SSL válido + switch de DNS.

## 7) Pendientes / preguntas abiertas
1) Hosting definitivo: **Cloudflare Pages vs Netlify vs Vercel**.
2) DNS actual: hoy **NIC.ar → DigitalOcean DNS** con **MX a Google**. Pendiente: decidir si migrar nameservers a Cloudflare.
3) Blog:
   - Se mantiene y se automatiza con **PR con aprobación**.
   - Idiomas: **ES/EN/IT/PT**.
4) Formulario de contacto:
   - ¿Se necesita formulario (sin backend) o alcanza mail/WhatsApp?
5) “Estilo” a elegir: A / B / C.
6) SEO/AI-search: definir qué pruebas sociales habrá (logos, partners, métricas, bios) y assets descargables (checklists/scorecards).

---

## Notas operativas
- En el server actual, HTTPS está levantado pero con **self-signed** (no final). Para el sitio nuevo, se debe emitir certificado válido (Let’s Encrypt/Pages/Cloudflare).
- El sistema actual (Ubuntu 14.04) es EOL; el objetivo es **salir** de ese stack.
