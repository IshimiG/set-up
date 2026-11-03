#version 440
// La lámina de cristal del tema liquido, de una pasada (la usa Cristal.qml
// cuando Theme.vidrio). Cristal neutro y sencillo, como las baldosas de iOS 26:
// sin color propio, el del fondo desenfocado (lo pone Hyprland) se ve a
// través. Todo se calcula con la distancia con signo al borde de un rectángulo
// redondeado, en píxeles lógicos, así que vale igual para una pastilla de
// 26 px que para el cajón entero y sigue al tamaño mientras la isla se
// despliega.
//
// De dentro afuera:
//   1. El cuerpo: blanco muy translúcido (cuerpoArriba → cuerpoAbajo). Con
//      `velo`, un velo neutro oscuro encima, para leer sobre una ventana clara.
//   2. El grosor: un resplandor blanco muy fino por dentro del canto, más
//      claro donde le da la luz (arriba a la izquierda), que se apaga hacia
//      dentro en `grosor`.
//   3. Un brillo ancho y muy tenue en la parte de arriba.
//   4. El canto: un filo blanco cuyo alfa sigue las paradas canto0..canto4 por
//      la diagonal (más brillante arriba a la izquierda, tenue abajo), más
//      fuerte en las esquinas y donde le da la luz.
//   5. El brillo especular: una media luna fina por dentro del canto de
//      arriba y un reflejo más tenue en el de abajo.
//
// Se compila con qsb (paquete qt6-shadertools); el .qsb va en el repo, así que
// en una máquina sólo hace falta para volver a compilarlo tras tocar esto:
//   /usr/lib/qt6/bin/qsb --qt6 -o cristal.frag.qsb cristal.frag
// pruebas/temas/prueba.sh comprueba que el .qsb está al día.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 tam;           // ancho y alto, en píxeles lógicos
    float radio;
    float borde;        // grueso del canto
    float grosor;       // ancho del resplandor de dentro del canto
    float brillo;       // 0 = sin brillo especular ni brillo de arriba
    float esquina;      // alfa del canto en las esquinas
    float medio;        // alfa del canto en el medio de los lados
    float luz;          // cuánto aviva la luz el canto de arriba
    float reflejo;      // el reflejo del canto de abajo
    float sheen;        // el brillo ancho de arriba
    vec4 cuerpoArriba;  // colores sin premultiplicar
    vec4 cuerpoAbajo;
    vec4 velo;          // el velo de lectura (su alfa ya trae cuánto)
    vec4 canto0;        // las paradas del canto: arriba a la izquierda
    vec4 canto1;
    vec4 canto2;
    vec4 canto3;
    vec4 canto4;        // abajo a la derecha
};

// Distancia con signo a un rectángulo redondeado centrado en el origen:
// negativa dentro, 0 en el borde.
float rectRedondo(vec2 p, vec2 b, float r)
{
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

// La normal hacia fuera del borde más cercano.
vec2 normal(vec2 p, vec2 b, float r)
{
    vec2 q = abs(p) - b + r;
    vec2 n;
    if (q.x > 0.0 && q.y > 0.0)
        n = normalize(q);
    else
        n = q.x > q.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    return n * sign(p + 1e-4);
}

// Las paradas del canto, de 0 (arriba a la izquierda) a 1 (abajo a la derecha).
vec4 parada(float s)
{
    s = clamp(s, 0.0, 1.0) * 4.0;
    if (s < 1.0)
        return mix(canto0, canto1, s);
    if (s < 2.0)
        return mix(canto1, canto2, s - 1.0);
    if (s < 3.0)
        return mix(canto2, canto3, s - 2.0);
    return mix(canto3, canto4, s - 3.0);
}

// Pone `capa` (premultiplicada) encima de `base` (premultiplicada).
vec4 encima(vec4 capa, vec4 base)
{
    return capa + base * (1.0 - capa.a);
}

vec4 premul(vec3 c, float a)
{
    return vec4(c * a, a);
}

void main()
{
    vec2 uv = qt_TexCoord0;
    vec2 b = tam * 0.5;
    vec2 p = uv * tam - b;
    float r = min(radio, min(b.x, b.y));
    float d = rectRedondo(p, b, r);
    float prof = -d;                       // cuánto se mete hacia dentro
    float aa = max(fwidth(d), 0.35);
    float dentro = clamp(0.5 - d / aa, 0.0, 1.0);
    if (dentro <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 n = normal(p, b, r);
    // La luz viene de arriba a la izquierda.
    vec2 L = normalize(vec2(-0.45, -1.0));
    float deLuz = max(dot(n, L), 0.0);
    float contraLuz = max(dot(n, -L), 0.0);

    // Esquinas: 1 en el redondeo y cerca de él, 0 en el medio de un lado.
    float caida = clamp(min(tam.x, tam.y) * 0.6, 14.0, 90.0);
    vec2 e = clamp((abs(p) - (b - r - caida)) / (r + caida), 0.0, 1.0);
    float esq = smoothstep(0.0, 1.0, e.x) * smoothstep(0.0, 1.0, e.y);
    float fuerza = mix(medio, esquina, esq);

    // La diagonal, de arriba a la izquierda a abajo a la derecha.
    float s = (uv.x + uv.y) * 0.5;
    float x = max(prof - borde, 0.0);

    // 1. El cuerpo, y el velo de lectura.
    vec4 c = premul(mix(cuerpoArriba.rgb, cuerpoAbajo.rgb, uv.y), mix(cuerpoArriba.a, cuerpoAbajo.a, uv.y));
    c = encima(premul(velo.rgb, velo.a), c);

    // 2. El grosor: la luz que entra por el canto y se queda en el vidrio.
    if (grosor > 0.0) {
        float a = parada(s).a * fuerza * exp(-x / grosor) * step(borde * 0.5, prof);
        c = encima(premul(vec3(1.0), 0.35 * a * (0.4 + 0.6 * deLuz + 0.3 * contraLuz)), c);
    }

    // 3. El brillo ancho de arriba: de sheen a nada en el tercio de arriba.
    if (brillo > 0.0 && sheen > 0.0) {
        float alto = max(tam.y * 0.38, 6.0);
        float sh = (1.0 - smoothstep(0.0, alto, uv.y * tam.y)) * smoothstep(0.0, borde + 1.0, prof);
        c = encima(premul(vec3(1.0), sheen * sh * brillo), c);
    }

    // 4. El canto.
    float filo = clamp((borde - prof) / aa + 0.5, 0.0, 1.0);
    float alfa = parada(s).a * fuerza;
    alfa = clamp(alfa + luz * 0.5 * pow(deLuz, 3.0) + reflejo * 0.4 * pow(contraLuz, 3.0), 0.0, 1.0);
    c = encima(premul(vec3(1.0), alfa * filo), c);

    // 5. El brillo especular: una media luna blanca justo por dentro del
    // canto de arriba, más intensa hacia la esquina de arriba a la izquierda,
    // y un reflejo más tenue en el canto de abajo.
    if (brillo > 0.0) {
        float media = exp(-x / max(grosor * 0.5, 0.8)) * step(borde * 0.6, prof);
        float arriba = pow(deLuz, 4.0) * (0.5 + 0.5 * (1.0 - uv.x));
        c = encima(premul(vec3(1.0), clamp(0.6 * luz * media * arriba, 0.0, 1.0) * brillo), c);
        c = encima(premul(vec3(1.0), 0.5 * reflejo * media * pow(contraLuz, 3.0) * brillo), c);
    }

    fragColor = c * dentro * qt_Opacity;
}
