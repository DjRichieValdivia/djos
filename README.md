# DJOS

Sistema operativo para DJs y producción de audio: Fedora atómico con KDE Plasma, armado sobre
[Universal Blue](https://universal-blue.org) (Fedora Kinoite + driver de NVIDIA).

- **Se actualiza solo**: GitHub arma la imagen todos los días con las actualizaciones de Fedora; la PC la baja en
  segundo plano y la aplica al reiniciar. Si algo sale mal, se elige la versión anterior en el menú de arranque.
- **Audio en tiempo real**: núcleo apropiativo (`preempt=full`, `threadirqs`), prioridad para las interrupciones de
  USB y sonido, grupo `audio` con tiempo real y memoria bloqueada, USB sin ahorro de energía, PipeWire a 48 kHz con
  buffers chicos permitidos, placas que nunca se suspenden.
- **Rápido y liviano**: sin KDE Connect, escritorio remoto, modo juego, AirPlay, módem, Akonadi ni indexado de
  archivos; perfil de energía "Rendimiento".
- **Sin cifrado de disco.**

## Archivos

| Ruta | Para qué |
|---|---|
| `Containerfile` | receta de la imagen |
| `build/build.sh` | qué se saca, qué servicios se apagan, nombre del sistema |
| `system/` | archivos que se copian tal cual a la raíz del sistema |
| `.github/workflows/build.yml` | armado automático diario |

## Actualizar a mano

```bash
sudo bootc upgrade
```

## Volver a la versión anterior

```bash
sudo bootc rollback
```
