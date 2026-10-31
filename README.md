# OAR Mod Menu

Mod menu para **One-armed Robber** en Windows. Versión **v1.0.0**.

- Selector de los 14 atracos detectados en el build 26319483.
- Recarga del atraco actual seleccionándolo de nuevo desde el anfitrión.
- Probador del catálogo completo instalado: 27 máscaras y gorros, 23 atuendos y 17 bailes o gestos, aunque no estén en tu inventario.
- 18 skins para el arma principal y secundaria, con opción de volver al acabado de fábrica.
- El gesto equipado se ejecuta con la tecla configurada en el juego (F por defecto).

## Instalación

1. Cierra el juego.
2. Descarga `OAR-Mod-Menu-v1.0.0-Setup.exe` desde Releases y ejecútalo.
3. Comprueba la carpeta detectada de Steam y pulsa **Instalar / actualizar**.
4. Abre el juego desde Steam y pulsa **F6**.

El instalador es autónomo: no requiere Python, .NET ni descargas adicionales en el equipo de destino. Incluye la compilación de UE4SS comprobada para este menú.

Si Windows deniega la escritura en la carpeta del juego, abre el instalador con **Ejecutar como administrador**. Para retirarlo, cierra el juego, vuelve a abrir el mismo instalador y pulsa **Desinstalar**. Se conservan los archivos ajenos o modificados y las copias de seguridad.

También se incluye un ZIP portátil. Su contenido se coloca en `One-armed robber/OAR/Binaries/Win64`. Si ya utilizas UE4SS, copia solamente `Mods/OARPracticeMenu` a su directorio `Mods` y conserva tu cargador y configuración. El instalador admite las estructuras estándar con UE4SS en Win64 o en Win64/ue4ss, siempre que la compilación existente coincida con la fijada.

## Controles

| Tecla | Acción |
|---|---|
| F6 | Abrir o cerrar el menú |
| F5 | Cambiar entre mapas, máscaras, atuendos, gestos y armas |
| F7 / F8 | Opción anterior / siguiente |
| F9 | Equipar el cosmético seleccionado |
| F9, dos veces en cinco segundos | Cargar el mapa seleccionado |

Para recargar el atraco, selecciona su mapa y pulsa F9 dos veces. Las opciones de cosméticos se actualizan al abrir el menú o cambiar de sección.

El funcionamiento de mapas y cosméticos está comprobado en multijugador. En una sala online, el anfitrión controla los cambios de mapa y los reinicios. El menú no necesita instalarse en los invitados para las funciones de mapas. La apariencia utiliza las funciones y la replicación del propio juego.

## Alcance y compatibilidad

El catálogo de mapas procede de Steam build **26319483**, Unreal Engine **4.27.2**. Los tutoriales y escenarios internos de desarrollo no se incluyen como atracos online.

El probador carga las clases de apariencia y la tabla de skins del juego instalado, incluidos los cosméticos que no posees. Los objetos abstractos y los de prueba interna de desarrollo se omiten. Los artículos propios o equipados también se incorporan para conservar la compatibilidad con objetos heredados.

F9 aplica la selección mediante funciones nativas; la apariencia puede guardarse y conservarse al reiniciar. Para volver al aspecto anterior, selecciónalo de nuevo; para las armas, elige **De fábrica**. No se conceden objetos a la cuenta ni se modifican Heist Coins, compras o el inventario remoto de Steam. No se añade un modo que aísle automáticamente los guardados o las recompensas de las prácticas.

Las actualizaciones del juego pueden cambiar las funciones reflejadas.

## Compilar

En Windows x64, instala un SDK de .NET 8 o posterior:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build.ps1
```

El script verifica el SHA-256 de UE4SS y compila un instalador autónomo. Los artefactos quedan en `dist/`.

`vendor/` contiene la dependencia de UE4SS para poder reconstruir esta versión aunque cambie la release experimental original. No se incluyen archivos extraídos del juego.

## Código y licencia

El mod está en `src/OARPracticeMenu/Scripts` y el instalador en `installer/`.

Código del proyecto: MIT. UE4SS: MIT, con su aviso en `vendor/UE4SS-LICENSE.txt`. Este proyecto es independiente de Duhndal y Valve.
