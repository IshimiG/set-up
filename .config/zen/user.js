// Ajustes de memoria de Zen Browser. setup.sh enlaza este fichero como user.js
// en el perfil por defecto (~/.config/zen/<perfil>/user.js); Zen lo lee al
// arrancar y lo aplica por encima de prefs.js. Para quitar un ajuste, bórralo
// de aquí y reinicia Zen (el valor se queda en prefs.js hasta que lo cambies).

// Procesos de contenido: 4 en vez de los 8 por defecto. Cada proceso cuesta
// unos 100-200 MiB; las pestañas se reparten entre ellos.
user_pref("dom.ipc.processCount", 4);

// Con poca memoria libre, descarga las pestañas que no se usan.
user_pref("browser.tabs.unloadOnLowMemory", true);

// Se considera poca memoria cuando queda menos de este porcentaje (%) libre.
user_pref("browser.low_commit_space_threshold_percent", 20);

// Caché de memoria: máximo 256 MiB (el valor va en KiB).
user_pref("browser.cache.memory.capacity", 262144);

// Decodifica el vídeo con la gráfica (VA-API): menos CPU y menos memoria.
user_pref("media.ffmpeg.vaapi.enabled", true);

// Renderiza todo con WebRender (en la gráfica).
user_pref("gfx.webrender.all", true);

// Páginas completas que se guardan para atrás/adelante: 2 (por defecto, 8).
user_pref("browser.sessionhistory.max_total_viewers", 2);
