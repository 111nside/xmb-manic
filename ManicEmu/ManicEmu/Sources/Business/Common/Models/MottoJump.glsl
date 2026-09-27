// Motto Jump
// A ShaderToy-compatible 2.5D SDF illustration based on Motto's key art.

mat2 rot2(float a)
{
    float c = cos(a);
    float s = sin(a);
    return mat2(c, s, -s, c);
}

float smin(float a, float b, float k)
{
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float sdEllipse(vec2 p, vec2 r)
{
    return (length(p / r) - 1.0) * min(r.x, r.y);
}

float sdCapsule(vec2 p, vec2 a, vec2 b, float r)
{
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

float sdRoundBox(vec2 p, vec2 b, float r)
{
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

float sdTriangle(vec2 p, vec2 a, vec2 b, vec2 c)
{
    vec2 e0 = b - a;
    vec2 e1 = c - b;
    vec2 e2 = a - c;
    vec2 v0 = p - a;
    vec2 v1 = p - b;
    vec2 v2 = p - c;
    vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
    vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
    vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
    float s = sign(e0.x * e2.y - e0.y * e2.x);
    vec2 d = min(min(vec2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
                      vec2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
                      vec2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
    return -sqrt(d.x) * sign(d.y);
}

float fillMask(float d)
{
    float aa = max(fwidth(d), 1.25 / iResolution.y);
    return 1.0 - smoothstep(-aa, aa, d);
}

void paint(inout vec3 canvas, vec3 color, float d)
{
    canvas = mix(canvas, color, fillMask(d));
}

void paintMask(inout vec3 canvas, vec3 color, float mask)
{
    canvas = mix(canvas, color, clamp(mask, 0.0, 1.0));
}

float mottoMark(vec2 p)
{
    float d = sdCapsule(p, vec2(-0.155, -0.095), vec2(-0.015, 0.165), 0.041);
    d = min(d, sdCapsule(p, vec2(-0.015, 0.165), vec2(0.145, -0.095), 0.041));
    d = min(d, sdCapsule(p, vec2(0.118, -0.095), vec2(0.215, -0.095), 0.041));
    d = min(d, sdCapsule(p, vec2(-0.105, -0.015), vec2(0.105, -0.015), 0.034));
    return d;
}

float sparkleShape(vec2 p)
{
    p = abs(p);
    float vertical = p.x / 0.027 + p.y / 0.088 - 1.0;
    float horizontal = p.x / 0.068 + p.y / 0.026 - 1.0;
    return min(vertical, horizontal) * 0.035;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 screen = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    const vec3 BRAND_RED = vec3(1.000, 0.141, 0.259); // #FF2442
    const vec3 RED_LIGHT = vec3(1.000, 0.300, 0.365);
    const vec3 RED_DARK = vec3(0.565, 0.055, 0.110);
    const vec3 OUTLINE = vec3(0.365, 0.028, 0.070);
    const vec3 CREAM = vec3(1.000, 0.965, 0.865);
    const vec3 INK = vec3(0.055, 0.045, 0.060);
    const vec3 GOLD = vec3(1.000, 0.650, 0.120);

    // Dark burgundy stage keeps the red mascot saturated and readable.
    float vignette = smoothstep(0.18, 0.78, length(screen * vec2(0.82, 1.0)));
    float halo = exp(-3.8 * dot(screen - vec2(0.0, 0.04),
                               screen - vec2(0.0, 0.04)));
    vec3 color = mix(vec3(0.075, 0.004, 0.016),
                     vec3(0.215, 0.012, 0.045), halo);
    color *= 1.0 - 0.58 * vignette;

    // Subtle floor and contact shadow.
    float floorGlow = exp(-20.0 * abs(screen.y + 0.455))
                    * exp(-3.5 * screen.x * screen.x);
    color += vec3(0.22, 0.025, 0.055) * floorGlow * 0.32;
    vec2 shadowP = (screen - vec2(0.0, -0.442)) / vec2(0.34, 0.050);
    float shadow = (1.0 - smoothstep(0.55, 1.25, length(shadowP))) * 0.58;
    color = mix(color, vec3(0.018, 0.001, 0.005), shadow);

    // Whole-character animation: restrained two-degree rotation and tiny lift.
    float angle = sin(iTime * 0.78) * 0.035;
    float bob = sin(iTime * 1.56) * 0.006;
    vec2 p = screen - vec2(0.0, bob);
    p = rot2(-angle) * p;

    // Shared glossy red, shaded vertically without changing the brand hue.
    float redShade = clamp((p.y + 0.45) / 0.95, 0.0, 1.0);
    vec3 redBody = mix(BRAND_RED * 0.72, BRAND_RED, redShade);

    // Back legs: broad, rounded and visibly separated.
    vec2 leftFootP = rot2(-0.10) * (p - vec2(-0.145, -0.350));
    vec2 rightFootP = rot2(0.10) * (p - vec2(0.145, -0.350));
    float leftFoot = sdEllipse(leftFootP, vec2(0.175, 0.137));
    float rightFoot = sdEllipse(rightFootP, vec2(0.175, 0.137));
    paint(color, OUTLINE, leftFoot - 0.012);
    paint(color, mix(RED_DARK, BRAND_RED, 0.58), leftFoot);
    paint(color, OUTLINE, rightFoot - 0.012);
    paint(color, mix(RED_DARK, BRAND_RED, 0.64), rightFoot);

    // Relaxed arm on the viewer's left.
    float leftArm = sdCapsule(p, vec2(-0.215, -0.055),
                             vec2(-0.370, -0.205), 0.086);
    float leftHand = sdEllipse(rot2(-0.18) * (p - vec2(-0.405, -0.225)),
                               vec2(0.118, 0.085));
    float leftLimb = smin(leftArm, leftHand, 0.030);
    paint(color, OUTLINE, leftLimb - 0.012);
    paint(color, mix(RED_DARK, BRAND_RED, 0.70), leftLimb);

    // Raised arm foundation on the viewer's right.
    float rightArm = sdCapsule(p, vec2(0.205, -0.015),
                              vec2(0.365, 0.145), 0.099);
    float fist = sdEllipse(rot2(-0.18) * (p - vec2(0.405, 0.165)),
                           vec2(0.128, 0.145));
    float raisedLimb = smin(rightArm, fist, 0.040);
    paint(color, OUTLINE, raisedLimb - 0.013);
    paint(color, mix(RED_DARK, BRAND_RED, 0.78), raisedLimb);

    // Pear-shaped torso.
    float bodyTop = sdEllipse(p - vec2(0.0, -0.075), vec2(0.260, 0.255));
    float bodyBottom = sdEllipse(p - vec2(0.0, -0.220), vec2(0.292, 0.245));
    float body = smin(bodyTop, bodyBottom, 0.095);
    paint(color, OUTLINE, body - 0.014);
    paint(color, redBody, body);

    // Torso volume: shaded lower-right edge and a restrained upper-left gloss.
    float bodyInside = fillMask(body + 0.006);
    float bodyShade = smoothstep(0.10, 0.37, length(p - vec2(0.16, -0.27)));
    paintMask(color, RED_DARK, bodyInside * bodyShade * 0.18);
    float bodyGloss = exp(-120.0 * dot(p - vec2(-0.135, 0.020),
                                      p - vec2(-0.135, 0.020)));
    paintMask(color, RED_LIGHT, bodyInside * bodyGloss * 0.26);

    // Large circular hood, deliberately wider than the torso.
    vec2 headP = p - vec2(-0.010, 0.195);
    float hood = sdEllipse(headP, vec2(0.365, 0.323));
    paint(color, OUTLINE, hood - 0.015);
    vec3 hoodColor = mix(BRAND_RED * 0.78, BRAND_RED,
                         clamp((p.y + 0.05) / 0.58, 0.0, 1.0));
    paint(color, hoodColor, hood);

    float hoodInside = fillMask(hood + 0.006);
    float hoodShade = smoothstep(0.18, 0.52, length(p - vec2(0.22, 0.04)));
    paintMask(color, RED_DARK, hoodInside * hoodShade * 0.16);
    float hoodGloss = exp(-105.0 * dot(p - vec2(-0.145, 0.390),
                                      p - vec2(-0.145, 0.390)));
    paintMask(color, RED_LIGHT, hoodInside * hoodGloss * 0.34);

    // Cream face inset: broad horizontal oval with a substantial red rim.
    vec2 faceP = p - vec2(-0.012, 0.185);
    faceP.y += 0.035 * (faceP.x / 0.30) * (faceP.x / 0.30);
    float face = sdEllipse(faceP, vec2(0.292, 0.235));
    paint(color, OUTLINE, face - 0.007);
    vec3 faceColor = mix(vec3(0.910, 0.830, 0.690), CREAM,
                         clamp((p.y + 0.02) / 0.46, 0.0, 1.0));
    paint(color, faceColor, face);

    float faceInside = fillMask(face + 0.004);
    float faceGlow = exp(-95.0 * dot(p - vec2(-0.145, 0.340),
                                    p - vec2(-0.145, 0.340)));
    paintMask(color, vec3(1.0, 0.995, 0.950), faceInside * faceGlow * 0.42);
    float faceShade = smoothstep(0.16, 0.37, length(p - vec2(0.19, 0.045)));
    paintMask(color, vec3(0.73, 0.62, 0.53), faceInside * faceShade * 0.12);

    // Open eye on the viewer's left.
    vec2 eyeP = rot2(-0.03) * (p - vec2(-0.132, 0.220));
    float openEye = sdEllipse(eyeP, vec2(0.057, 0.094));
    paint(color, INK, openEye);
    float irisGlow = sdEllipse(eyeP - vec2(0.010, -0.030), vec2(0.037, 0.045));
    paint(color, vec3(0.115, 0.105, 0.125), irisGlow);
    paint(color, vec3(1.0), sdEllipse(eyeP - vec2(-0.016, 0.040),
                                     vec2(0.016, 0.022)));

    // Friendly curved wink on the viewer's right.
    float wink0 = sdCapsule(p, vec2(0.075, 0.220), vec2(0.128, 0.263), 0.014);
    float wink1 = sdCapsule(p, vec2(0.128, 0.263), vec2(0.205, 0.235), 0.014);
    float wink2 = sdCapsule(p, vec2(0.143, 0.218), vec2(0.210, 0.213), 0.011);
    paint(color, INK, min(wink0, min(wink1, wink2)));

    // Open smile with a dark cavity and visible tongue.
    vec2 mouthP = p - vec2(-0.004, 0.095);
    float mouth = sdEllipse(mouthP, vec2(0.081, 0.074));
    paint(color, OUTLINE, mouth - 0.006);
    paint(color, vec3(0.255, 0.020, 0.050), mouth);
    vec2 tongueP = p - vec2(-0.004, 0.064);
    float tongue = sdEllipse(tongueP, vec2(0.060, 0.032));
    float tongueClip = max(tongue, mouth);
    paint(color, vec3(1.0, 0.310, 0.390), tongueClip);

    // Motto's cream chest mark, including the angular center cut.
    vec2 markP = p - vec2(0.0, -0.145);
    float mark = mottoMark(markP);
    paint(color, vec3(0.965, 0.900, 0.750), mark - 0.006);
    paint(color, CREAM, mark);
    float markCut = sdTriangle(markP,
                               vec2(-0.027, 0.025),
                               vec2(0.028, 0.025),
                               vec2(0.002, 0.080));
    paint(color, BRAND_RED * 0.92, markCut);

    // Thumb and fingertip are drawn last for a readable thumbs-up silhouette.
    float thumbStem = sdCapsule(p, vec2(0.420, 0.215),
                               vec2(0.447, 0.385), 0.068);
    float thumbTip = sdEllipse(rot2(-0.10) * (p - vec2(0.450, 0.405)),
                               vec2(0.071, 0.083));
    float thumb = smin(thumbStem, thumbTip, 0.025);
    paint(color, OUTLINE, thumb - 0.012);
    paint(color, mix(BRAND_RED, RED_LIGHT, 0.16), thumb);

    // Palm/finger separation gives the hand structure absent from the first pass.
    for (int i = 0; i < 3; ++i)
    {
        float y = 0.185 - float(i) * 0.055;
        float crease = sdCapsule(p, vec2(0.375, y),
                                vec2(0.462, y - 0.010), 0.006);
        paint(color, RED_DARK, crease);
    }
    float thumbCrease = sdCapsule(p, vec2(0.390, 0.245),
                                 vec2(0.430, 0.225), 0.006);
    paint(color, RED_DARK, thumbCrease);

    // Small shell highlights echo the glossy key-art treatment.
    float headSpec = sdEllipse(p - vec2(-0.205, 0.418), vec2(0.070, 0.032));
    paintMask(color, vec3(1.0, 0.72, 0.72),
              fillMask(headSpec) * hoodInside * 0.46);
    float armSpec = sdEllipse(rot2(-0.35) * (p - vec2(-0.425, -0.195)),
                              vec2(0.034, 0.013));
    paintMask(color, vec3(1.0, 0.72, 0.72),
              fillMask(armSpec) * 0.52);

    // Gold four-point sparkle beside the raised thumb.
    vec2 starP = screen - vec2(0.570, 0.330);
    starP = rot2(-iTime * 0.22) * starP;
    float star = sparkleShape(starP);
    paint(color, vec3(0.37, 0.12, 0.015), star - 0.007);
    paint(color, GOLD, star);
    paint(color, vec3(1.0, 0.92, 0.47),
          sparkleShape(starP * 1.65));

    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
