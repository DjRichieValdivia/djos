# DJOS

Sistema operativo para DJs y producción de audio: Fedora atómico con KDE Plasma, armado sobre
[Universal Blue](https://universal-blue.org) (Fedora Kinoite + driver de NVIDIA). Interfaz en inglés (EE. UU.).

- **Se actualiza solo**: GitHub arma la imagen todos los días con las actualizaciones de Fedora; la PC la baja en
  segundo plano y la aplica al reiniciar. Nunca mientras suena un set. Si algo sale mal, se elige la versión
  anterior en el menú de arranque. Las versiones grandes de Fedora se ofrecen con un botón, 4 semanas después.
- **Audio en tiempo real**: núcleo apropiativo (`preempt=full`, `threadirqs`), prioridad para las interrupciones de
  USB y sonido (en núcleos de rendimiento), grupo `audio` con tiempo real y memoria bloqueada, USB sin ahorro de
  energía, perfil de `tuned` para audio, PipeWire a 48 kHz con buffers chicos permitidos.
- **Aspecto propio**: tema DJOS (grafito y naranja), íconos Papirus con carpetas naranjas, letra Inter, fondos,
  pantalla de arranque, de inicio de sesión y de bloqueo, barra de tareas y menú propios, cada monitor a su
  frecuencia más alta.
- **DJOS Center**: audio (placas, frecuencia, buffer, lista de control de tiempo real), rendimiento, actualizaciones,
  programas y plugins, discos de música. También está en Configuración, en la sección DJOS.
- **Programas para DJs y producción**: Ardour, Carla, Audacity, Kid3, Picard, SoundConverter, Sonic Visualiser,
  Haruna, qpwgraph y plugins LV2/VST3/CLAP (LSP, x42, Calf, ZAM, ZynAddSubFX) ya incluidos; Mixxx, Bitwig, REAPER,
  OBS y paquetes de plugins para los DAW de Flathub con un clic.
- **Liviano**: sin KDE Connect, escritorio remoto, modo juego, teclados asiáticos, drivers de impresoras, bases de
  datos, bóveda cifrada ni indexado de archivos; secciones inútiles de Configuración escondidas.
- **Sin cifrado de disco.**

## Archivos

| Ruta | Para qué |
|---|---|
| `Containerfile` | receta de la imagen |
| `build/build.sh` | qué se saca y se agrega, servicios, aspecto, pantalla de arranque, nombre del sistema |
| `system/` | archivos que se copian tal cual a la raíz del sistema |
| `branding/` | logo (SVG) y `gen.py`, que genera fondos, logo con nombre y vistas previas |
| `.github/workflows/build.yml` | armado automático diario |

## Actualizar a mano

```bash
sudo bootc upgrade
```

## Volver a la versión anterior

```bash
sudo bootc rollback
```
