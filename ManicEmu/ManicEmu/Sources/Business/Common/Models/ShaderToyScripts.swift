//
//  ShaderToyScripts.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/17.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

extension ShaderToy {
    //And390
    static let InsideTheMatrix = """
        /*
          Feel free to do anything you want with this code.
          This shader uses "runes" code by FabriceNeyret2 (https://www.shadertoy.com/view/4ltyDM)
          which is based on "runes" by otaviogood (https://shadertoy.com/view/MsXSRn).
          These random runes look good as matrix symbols and have acceptable performance.
        */

        const int ITERATIONS = 20;   //use less value if you need more performance
        const float SPEED = 1.;

        const float STRIP_CHARS_MIN =  7.;
        const float STRIP_CHARS_MAX = 40.;
        const float STRIP_CHAR_HEIGHT = 0.15;
        const float STRIP_CHAR_WIDTH = 0.10;
        const float ZCELL_SIZE = 1. * (STRIP_CHAR_HEIGHT * STRIP_CHARS_MAX);  //the multiplier can't be less than 1.
        const float XYCELL_SIZE = 12. * STRIP_CHAR_WIDTH;  //the multiplier can't be less than 1.

        const int BLOCK_SIZE = 10;  //in cells
        const int BLOCK_GAP = 2;    //in cells

        const float WALK_SPEED = 1. * XYCELL_SIZE;
        const float BLOCKS_BEFORE_TURN = 3.;


        const float PI = 3.14159265359;


        //        ----  random  ----
        // Precision-stable hashes: avoid sin(large) precision loss after long iTime.

        float hash11(float p) {
            p = fract(p * 0.1031);
            p *= p + 33.33;
            p *= p + p;
            return fract(p);
        }

        float hash(float v) {
            return hash11(v);
        }

        float hash(vec2 v) {
            vec3 p3 = fract(vec3(v.xyx) * 0.1031);
            p3 += dot(p3, p3.yzx + 33.33);
            return fract((p3.x + p3.y) * p3.z);
        }

        vec2 hash2(vec2 v)
        {
            vec3 p3 = fract(vec3(v.xyx) * vec3(0.1031, 0.1030, 0.0973));
            p3 += dot(p3, p3.yzx + 33.33);
            return fract((p3.xx + p3.yz) * p3.zy);
        }

        vec4 hash4(vec2 v)
        {
            vec4 p4 = fract(vec4(v.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
            p4 += dot(p4, p4.wzxy + 33.33);
            return fract((p4.xxyz + p4.yzzw) * p4.zywx);
        }

        vec4 hash4(vec3 v)
        {
            vec4 p4 = fract(vec4(v.xyzx) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
            p4 += dot(p4, p4.wzxy + 33.33);
            return fract((p4.xxyz + p4.yzzw) * p4.zywx);
        }


        //        ----  symbols  ----
        //  Slightly modified version of "runes" by FabriceNeyret2 -  https://www.shadertoy.com/view/4ltyDM
        //  Which is based on "runes" by otaviogood -  https://shadertoy.com/view/MsXSRn

        float rune_line(vec2 p, vec2 a, vec2 b) {   // from https://www.shadertoy.com/view/4dcfW8
            p -= a, b -= a;
            float h = clamp(dot(p, b) / dot(b, b), 0., 1.);   // proj coord on line
            return length(p - b * h);                         // dist to segment
        }

        float rune(vec2 U, vec2 seed, float highlight)
        {
            float d = 1e5;
            for (int i = 0; i < 4; i++)    // number of strokes
            {
                vec4 pos = hash4(seed);
                seed += 1.;

                // each rune touches the edge of its box on all 4 sides
                if (i == 0) pos.y = .0;
                if (i == 1) pos.x = .999;
                if (i == 2) pos.x = .0;
                if (i == 3) pos.y = .999;
                // snap the random line endpoints to a grid 2x3
                vec4 snaps = vec4(2, 3, 2, 3);
                pos = ( floor(pos * snaps) + .5) / snaps;

                if (pos.xy != pos.zw)  //filter out single points (when start and end are the same)
                    d = min(d, rune_line(U, pos.xy, pos.zw + .001) ); // closest line
            }
            return smoothstep(0.1, 0., d) + highlight*smoothstep(0.4, 0., d);
        }

        float random_char(vec2 outer, vec2 inner, float highlight) {
            vec2 seed = vec2(dot(outer, vec2(269.5, 183.3)), dot(outer, vec2(113.5, 271.9)));
            return rune(inner, seed, highlight);
        }


        //        ----  digital rain  ----

        // xy - horizontal, z - vertical
        vec3 rain(vec3 ro3, vec3 rd3, float time) {
            vec4 result = vec4(0.);

            // normalized 2d projection
            vec2 ro2 = vec2(ro3);
            vec2 rd2 = normalize(vec2(rd3));

            // we use formulas `ro3 + rd3 * t3` and `ro2 + rd2 * t2`, `t3_to_t2` is a multiplier to convert t3 to t2
            bool prefer_dx = abs(rd2.x) > abs(rd2.y);
            float t3_to_t2 = prefer_dx ? rd3.x / rd2.x : rd3.y / rd2.y;

            // at first, horizontal space (xy) is divided into cells (which are columns in 3D)
            // then each xy-cell is divided into vertical cells (along z) - each of these cells contains one raindrop

            ivec3 cell_side = ivec3(step(0., rd3));      //for positive rd.x use cell side with higher x (1) as the next side, for negative - with lower x (0), the same for y and z
            ivec3 cell_shift = ivec3(sign(rd3));         //shift to move to the next cell

            //  move through xy-cells in the ray direction
            float t2 = 0.;  // the ray formula is: ro2 + rd2 * t2, where t2 is positive as the ray has a direction.
            ivec2 next_cell = ivec2(floor(ro2/XYCELL_SIZE));  //first cell index where ray origin is located
            for (int i=0; i<ITERATIONS; i++) {
                ivec2 cell = next_cell;  //save cell value before changing
                float t2s = t2;          //and t

                //  find the intersection with the nearest side of the current xy-cell (since we know the direction, we only need to check one vertical side and one horizontal side)
                vec2 side = vec2(next_cell + cell_side.xy) * XYCELL_SIZE;  //side.x is x coord of the y-axis side, side.y - y of the x-axis side
                vec2 t2_side = (side - ro2) / rd2;  // t2_side.x and t2_side.y are two candidates for the next value of t2, we need the nearest
                if (t2_side.x < t2_side.y) {
                    t2 = t2_side.x;
                    next_cell.x += cell_shift.x;  //cross through the y-axis side
                } else {
                    t2 = t2_side.y;
                    next_cell.y += cell_shift.y;  //cross through the x-axis side
                }
                //now t2 is the value of the end point in the current cell (and the same point is the start value in the next cell)

                //  gap cells
                vec2 cell_in_block = fract(vec2(cell) / float(BLOCK_SIZE));
                float gap = float(BLOCK_GAP) / float(BLOCK_SIZE);
                if (cell_in_block.x < gap || cell_in_block.y < gap || (cell_in_block.x < (gap+0.1) && cell_in_block.y < (gap+0.1))) {
                    continue;
                }

                //  return to 3d - we have start and end points of the ray segment inside the column (t3s and t3e)
                float t3s = t2s / t3_to_t2;

                //  move through z-cells of the current column in the ray direction (don't need much to check, two nearest cells are enough)
                float pos_z = ro3.z + rd3.z * t3s;
                float xycell_hash = hash(vec2(cell));
                float z_shift = xycell_hash*11. - time * (0.5 + xycell_hash * 1.0 + xycell_hash * xycell_hash * 1.0 + pow(xycell_hash, 16.) * 3.0);  //a different z shift for each xy column
                float char_z_shift = floor(z_shift / STRIP_CHAR_HEIGHT);
                z_shift = char_z_shift * STRIP_CHAR_HEIGHT;
                int zcell = int(floor((pos_z - z_shift)/ZCELL_SIZE));  //z-cell index
                for (int j=0; j<2; j++) {  //2 iterations is enough if camera doesn't look much up or down
                    //  calcaulate coordinates of the target (raindrop)
                    vec4 cell_hash = hash4(vec3(ivec3(cell, zcell)));
                    vec4 cell_hash2 = fract(cell_hash * vec4(127.1, 311.7, 271.9, 124.6));

                    float chars_count = cell_hash.w * (STRIP_CHARS_MAX - STRIP_CHARS_MIN) + STRIP_CHARS_MIN;
                    float target_length = chars_count * STRIP_CHAR_HEIGHT;
                    float target_rad = STRIP_CHAR_WIDTH / 2.;
                    float target_z = (float(zcell)*ZCELL_SIZE + z_shift) + cell_hash.z * (ZCELL_SIZE - target_length);
                    vec2 target = vec2(cell) * XYCELL_SIZE + target_rad + cell_hash.xy * (XYCELL_SIZE - target_rad*2.);

                    //  We have a line segment (t0,t). Now calculate the distance between line segment and cell target (it's easier in 2d)
                    vec2 s = target - ro2;
                    float tmin = dot(s, rd2);  //tmin - point with minimal distance to target
                    if (tmin >= t2s && tmin <= t2) {
                        float u = s.x * rd2.y - s.y * rd2.x;  //horizontal coord in the matrix strip
                        if (abs(u) < target_rad) {
                            u = (u/target_rad + 1.) / 2.;
                            float z = ro3.z + rd3.z * tmin/t3_to_t2;
                            float v = (z - target_z) / target_length;  //vertical coord in the matrix strip
                            if (v >= 0.0 && v < 1.0) {
                                float c = floor(v * chars_count);  //symbol index relative to the start of the strip, with addition of char_z_shift it becomes an index relative to the whole cell
                                float q = fract(v * chars_count);
                                float char_z_hash = mod(char_z_shift, 1024.0);  //bounded for hash only; scroll geometry still uses char_z_shift
                                vec2 char_hash = hash2(vec2(c + char_z_hash, cell_hash2.x));
                                if (char_hash.x >= 0.1 || c == 0.) {  //10% of missed symbols
                                    float tick_rate = c == 0. ? 5.0 :  //first symbol is changed fast
                                            (1.0*cell_hash2.z +   //strips are changed sometime with different speed
                                                    cell_hash2.w*cell_hash2.w*4.*pow(char_hash.y, 4.));  //some symbols in some strips are changed relatively often
                                    float time_factor = floor(mod(time * tick_rate, 8192.0));
                                    float a = random_char(vec2(char_hash.x, time_factor), vec2(u,q), max(1., 3. - c/2.)*0.2);  //alpha
                                    a *= clamp((chars_count - 0.5 - c) / 2., 0., 1.);  //tail fade
                                    if (a > 0.) {
                                        float attenuation = 1. + pow(0.06*tmin/t3_to_t2, 2.);
                                        vec3 col = (c == 0. ? vec3(0.67, 1.0, 0.82) : vec3(0.25, 0.80, 0.40)) / attenuation;
                                        float a1 = result.a;
                                        result.a = a1 + (1. - a1) * a;
                                        result.xyz = (result.xyz * a1 + col * (1. - a1) * a) / result.a;
                                        if (result.a > 0.98)  return result.xyz;
                                    }
                                }
                            }
                        }
                    }
                    // not found in this cell - go to next vertical cell
                    zcell += cell_shift.z;
                }
                // go to next horizontal cell
            }

            return result.xyz * result.a;
        }


        //        ----  main, camera  ----

        vec2 rotate(vec2 v, float a) {
            float s = sin(a);
            float c = cos(a);
            mat2 m = mat2(c, -s, s, c);
            return m * v;
        }

        vec3 rotateX(vec3 v, float a) {
            float s = sin(a);
            float c = cos(a);
            return mat3(1.,0.,0.,0.,c,-s,0.,s,c) * v;
        }

        vec3 rotateY(vec3 v, float a) {
            float s = sin(a);
            float c = cos(a);
            return mat3(c,0.,-s,0.,1.,0.,s,0.,c) * v;
        }

        vec3 rotateZ(vec3 v, float a) {
            float s = sin(a);
            float c = cos(a);
            return mat3(c,-s,0.,s,c,0.,0.,0.,1.) * v;
        }

        float smoothstep1(float x) {
            return smoothstep(0., 1., x);
        }

        void mainImage( out vec4 fragColor, in vec2 fragCoord )
        {
            if (STRIP_CHAR_WIDTH > XYCELL_SIZE || STRIP_CHAR_HEIGHT * STRIP_CHARS_MAX > ZCELL_SIZE) {
                // error
                fragColor = vec4(1., 0., 0., 1.);
                return;
            }

            vec2 uv = (fragCoord.xy * 2. - iResolution.xy) / iResolution.y;

            float time = iTime * SPEED;

            const float turn_rad = 0.25 / BLOCKS_BEFORE_TURN;   //0 .. 0.5
            const float turn_abs_time = (PI/2.*turn_rad) * 1.5;  //multiplier different than 1 means a slow down on turns
            const float turn_time = turn_abs_time / (1. - 2.*turn_rad + turn_abs_time);  //0..1, but should be <= 0.5

            float level1_size = float(BLOCK_SIZE) * BLOCKS_BEFORE_TURN * XYCELL_SIZE;
            float level2_size = 4. * level1_size;
            float gap_size = float(BLOCK_GAP) * XYCELL_SIZE;

            vec3 ro = vec3(gap_size/2., gap_size/2., 0.);
            vec3 rd = vec3(uv.x, 2.0, uv.y);

            float tq = fract(time / (level2_size*4.) * WALK_SPEED);  //the whole cycle time counter
            float t8 = fract(tq*4.);  //time counter while walking on one of the four big sides
            float t1 = fract(t8*8.);  //time counter while walking on one of the eight sides of the big side

            vec2 prev;
            vec2 dir;
            if (tq < 0.25) {
                prev = vec2(0.,0.);
                dir = vec2(0.,1.);
            } else if (tq < 0.5) {
                prev = vec2(0.,1.);
                dir = vec2(1.,0.);
            } else if (tq < 0.75) {
                prev = vec2(1.,1.);
                dir = vec2(0.,-1.);
            } else {
                prev = vec2(1.,0.);
                dir = vec2(-1.,0.);
            }
            float angle = floor(tq * 4.);  //0..4 wich means 0..2*PI

            prev *= 4.;

            const float first_turn_look_angle = 0.4;
            const float second_turn_drift_angle = 0.5;
            const float fifth_turn_drift_angle = 0.25;

            vec2 turn;
            float turn_sign = 0.;
            vec2 dirL = rotate(dir, -PI/2.);
            vec2 dirR = -dirL;
            float up_down = 0.;
            float rotate_on_turns = 1.;
            float roll_on_turns = 1.;
            float add_angel = 0.;
            if (t8 < 0.125) {
                turn = dirL;
                //dir = dir;
                turn_sign = -1.;
                angle -= first_turn_look_angle * (max(0., t1 - (1. - turn_time*2.)) / turn_time - max(0., t1 - (1. - turn_time)) / turn_time * 2.5);
                roll_on_turns = 0.;
            } else if (t8 < 0.250) {
                prev += dir;
                turn = dir;
                dir = dirL;
                angle -= 1.;
                turn_sign = 1.;
                add_angel += first_turn_look_angle*0.5 + (-first_turn_look_angle*0.5+1.0+second_turn_drift_angle)*t1;
                rotate_on_turns = 0.;
                roll_on_turns = 0.;
            } else if (t8 < 0.375) {
                prev += dir + dirL;
                turn = dirR;
                //dir = dir;
                turn_sign = 1.;
                add_angel += second_turn_drift_angle*sqrt(1.-t1);
                //roll_on_turns = 0.;
            } else if (t8 < 0.5) {
                prev += dir + dir + dirL;
                turn = dirR;
                dir = dirR;
                angle += 1.;
                turn_sign = 0.;
                up_down = sin(t1*PI) * 0.37;
            } else if (t8 < 0.625) {
                prev += dir + dir;
                turn = dir;
                dir = dirR;
                angle += 1.;
                turn_sign = -1.;
                up_down = sin(-min(1., t1/(1.-turn_time))*PI) * 0.37;
            } else if (t8 < 0.750) {
                prev += dir + dir + dirR;
                turn = dirL;
                //dir = dir;
                turn_sign = -1.;
                add_angel -= (fifth_turn_drift_angle + 1.) * smoothstep1(t1);
                rotate_on_turns = 0.;
                roll_on_turns = 0.;
            } else if (t8 < 0.875) {
                prev += dir + dir + dir + dirR;
                turn = dir;
                dir = dirL;
                angle -= 1.;
                turn_sign = 1.;
                add_angel -= fifth_turn_drift_angle - smoothstep1(t1) * (fifth_turn_drift_angle * 2. + 1.);
                rotate_on_turns = 0.;
                roll_on_turns = 0.;
            } else {
                prev += dir + dir + dir;
                turn = dirR;
                //dir = dir;
                turn_sign = 1.;
                angle += fifth_turn_drift_angle * (1.5*min(1., (1.-t1)/turn_time) - 0.5*smoothstep1(1. - min(1.,t1/(1.-turn_time))));
            }

            if (iMouse.x > 10. || iMouse.y > 10.) {
                vec2 mouse = iMouse.xy / iResolution.xy * 2. - 1.;
                up_down = -0.7 * mouse.y;
                angle += mouse.x;
                rotate_on_turns = 1.;
                roll_on_turns = 0.;
            } else {
                angle += add_angel;
            }

            rd = rotateX(rd, up_down);

            vec2 p;
            if (turn_sign == 0.) {
                //  move forward
                p = prev + dir * (turn_rad + 1. * t1);
            }
            else if (t1 > (1. - turn_time)) {
                //  turn
                float tr = (t1 - (1. - turn_time)) / turn_time;
                vec2 c = prev + dir * (1. - turn_rad) + turn * turn_rad;
                p = c + turn_rad * rotate(dir, (tr - 1.) * turn_sign * PI/2.);
                angle += tr * turn_sign * rotate_on_turns;
                rd = rotateY(rd, sin(tr*turn_sign*PI) * 0.2 * roll_on_turns);  //roll
            }  else  {
                //  move forward
                t1 /= (1. - turn_time);
                p = prev + dir * (turn_rad + (1. - turn_rad*2.) * t1);
            }

            rd = rotateZ(rd, angle * PI/2.);

            ro.xy += level1_size * p;

            ro += rd * 0.2;
            rd = normalize(rd);

            vec3 col = rain(ro, rd, time);

            fragColor = vec4(col, 1.);
        }
        """
    
    //Xor
    static let Singularity = """
        /*
            "Singularity" by @XorDev

            A whirling blackhole.
            Feel free to code golf!

            FabriceNeyret2: -19
            dean_the_coder: -12
            iq: -4

            Metal-safe rewrite of the golfed Image pass. The original left `w`
            uninitialized, used log(0)/rcp(0) at the hole, and built a rotation
            with mat2(cos(t+vec4(0,33,11,0))). iOS 26 Metal fast-math turns
            those into NaN and the background goes black.
        */
        void mainImage(out vec4 O, vec2 F)
        {
            vec2 r = iResolution.xy;
            vec2 p = (F + F - r) / r.y / 0.7;
            vec2 d = vec2(-1.0, 1.0);

            float i = 0.2;
            vec2 b = p - i * d;
            float b2 = max(dot(b, b), 1e-8);
            vec2 skew = d / (0.1 + i / b2);
            vec2 c = p * mat2(1.0, 1.0, skew.x, skew.y);

            float a = max(dot(c, c), 1e-8);
            float theta = 0.5 * log(a) + iTime * i;
            float ct = cos(theta);
            float st = sin(theta);
            // Same as mat2(cos(theta + vec4(0,33,11,0))) — 33≈π/2, 11≈3π/2.
            vec2 v = (c * mat2(ct, -st, st, ct)) / i;

            vec2 w = vec2(0.0);
            for (int n = 0; n < 6; n++) {
                i += 1.0;
                v += 0.7 * sin(v.yx * i + iTime) / i + 0.5;
                w += 1.0 + sin(v);
            }

            i = length(sin(v / 0.3) * 0.4 + c * (3.0 + d));

            vec4 inner = clamp(c.x * vec4(0.6, -0.4, -1.0, 0.0), -40.0, 40.0);
            vec4 den = max(w.xyyx, vec4(1e-4));
            den *= max(2.0 + i * i * 0.25 - i, 0.25);
            den *= 0.5 + 1.0 / a;
            den *= 0.03 + abs(length(p) - 0.7);
            O = 1.0 - exp(-exp(inner) / den);
        }



        //Original [432]
        /*
        void mainImage(out vec4 O,in vec2 F)
        {
            vec2 p=(F*2.-iResolution.xy)/(iResolution.y*.7),
            d=vec2(-1,1),
            c=p*mat2(1,1,d/(.1+5./dot(5.*p-d,5.*p-d))),
            v=c;
            v*=mat2(cos(log(length(v))+iTime*.2+vec4(0,33,11,0)))*5.;
            vec4 o=vec4(0);
            for(float i;i++<9.;o+=sin(v.xyyx)+1.)
            v+=.7*sin(v.yx*i+iTime)/i+.5;
            O=1.-exp(-exp(c.x*vec4(.6,-.4,-1,0))/o
            /(.1+.1*pow(length(sin(v/.3)*.2+c*vec2(1,2))-1.,2.))
            /(1.+7.*exp(.3*c.y-dot(c,c)))
            /(.03+abs(length(p)-.7))*.2);
        }*/
        """
    
    /// 生成 FloatingPlaystationShapes GLSL
    /// - Parameters:
    ///   - darkBlue: 背景渐变深色端
    ///   - lightBlue: 背景渐变浅色端
    ///   - shapeGray: 形状颜色
    static func floatingPlaystationShapesScript(
        darkBlue: UIColor,
        lightBlue: UIColor,
        shapeGray: UIColor
    ) -> String {
        let darkBlueVec = glslVec3(darkBlue)
        let lightBlueVec = glslVec3(lightBlue)
        let shapeGrayVec = glslVec3(shapeGray)
        return """
        // Common parameters:
        #define SHAPE_SIZE 0.06
        #define BLUR 0.001
        #define VERTICAL_TRAVEL 0.1
        #define SPEED_TRAVEL 0.6
        #define SPEED_ROTATION 1.
        #define ALPHA .7

        // Colors (injected from Swift)
        #define DARK_BLUE \(darkBlueVec)
        #define LIGHT_BLUE \(lightBlueVec)
        #define SHAPE_GRAY \(shapeGrayVec)

        // Only applies to the circle and square
        #define INNER_CUTOUT_SCALE 0.7

        // The taper-off point for the triangle to be equilateral
        const float EQUILATERAL_HEIGHT =
                sqrt(pow(SHAPE_SIZE,2.) - pow(SHAPE_SIZE/2.,2.))
                - SHAPE_SIZE/2.;

        // NEW on Jul-24-2021: grid based rendering to improve performance
        // the old way is pretty terrible in hindsight
        #define NEW_RENDERER 1

        // Old renderer parameter:
        // set to an ammount similar to density 12 on the new renderer
        // so you can see the performance improvement
        // (at least I can see the difference on my 6 year old Macbook Air)
        #define SHAPE_AMOUNT 300.

        // New renderer parameters:
        #define DENSITY 8.
        // see the note in the main function
        #define PRESERVE_VERTICAL_TRAVEL 1

        // Helper functions grabbed from the internet
        float rand(vec2 co) {
            return fract(sin(dot(co.xy ,vec2(12.9898,78.233)))
                *43758.5453);
        }

        vec2 N22(vec2 p) {
            vec3 a = fract(p.xyx*vec3(123.34,234.34,345.65));
            a += dot(a, a+34.45);
            return fract(vec2(a.x*a.y,a.y*a.z));
        }

        // https://gist.github.com/companje/29408948f1e8be54dd5733a74ca49bb9
        float map(float value, float min1, float max1,
                float min2, float max2) {
            return min2 + (value - min1)*(max2 -min2)
                /(max1 - min1);
        }

        mat2 rotate(float angle) {
            return mat2(cos(angle),-sin(angle),
                sin(angle),cos(angle));
        }

        // Background gradient
        vec3 background(vec2 uv) {
            const float GRAD_START = 0.25, GRAD_STOP = 0.95;
            return mix(LIGHT_BLUE,DARK_BLUE,
                smoothstep(GRAD_START,GRAD_STOP,uv.y));
        }

        // Solid helper shapes
        float box(vec2 uv, float left, float right,
                float down, float up, float blur) {
            return smoothstep(left,left+blur,uv.x)
                *smoothstep(right,right-blur,uv.x)
                *smoothstep(down,down+blur,uv.y)
                *smoothstep(up,up-blur,uv.y);
        }

        float box(vec2 uv, float lowerBound, float upperBound,
                float blur) {
            return box(uv,lowerBound,upperBound,
                       lowerBound,upperBound,blur);
        }

        float triangleSolid(vec2 uv, float size, float height,
                float blur) {
            float sides = map(uv.y,-size/2.,height,size/2.,0.);
            return box(uv,-sides,sides,-size/2.,size/2.,blur);    
        }

        // Main shapes
        float circle(vec2 uv, float size, float blur, float alpha) {
            float radius = size/2.;
            return alpha*(smoothstep(radius+blur,radius,length(uv))
                - smoothstep(INNER_CUTOUT_SCALE*radius+blur,
                             INNER_CUTOUT_SCALE*radius,
                             length(uv)));
        }

        float X(vec2 uv, float size, float blur, float alpha) {
            float lower = -size/2., upper = size/2.;
            return alpha*(box(uv,lower,upper,lower/5.,upper/5.,blur)
                + box(uv,lower/5.,upper/5.,lower,upper,blur)
                - box(uv,lower/5.,upper/5.,blur));
        }

        float triangle(vec2 uv, float size, float height,
                float blur, float alpha) {
            vec2 innerCoord = uv*2.;
            const float BASE_SIZE = 0.05, SCALING_FACTOR = 0.01;
            innerCoord.y += SHAPE_SIZE/BASE_SIZE*SCALING_FACTOR;
            return alpha*(triangleSolid(uv,size,height,blur)
                - triangleSolid(innerCoord,size,height,blur));
        }

        float square(vec2 uv, float size, float blur, float alpha) {
            return alpha*(box(uv,-size/2.,size/2.,blur)
                - box(uv,-INNER_CUTOUT_SCALE*size/2.,
                      INNER_CUTOUT_SCALE*size/2.,blur));
        }

        vec2 sway(vec2 uv, vec2 start, float vertTravel,
                float timeShift) {
            return vec2(uv.x-start.x,uv.y-start.y
                        - vertTravel*sin(SPEED_TRAVEL
                                         *iTime-timeShift));
        }

        void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
            vec2 uv = fragCoord/iResolution.xy;
            float ASPECT_RATIO = iResolution.x/iResolution.y;
            uv.x *= ASPECT_RATIO;

            vec3 col = background(uv);
            
            #if NEW_RENDERER
            uv *= DENSITY;
            vec2 xy = fract(uv)-.5,  // point within a grid cell
                 id = floor(uv),     // the grid cell we are in
                 cid = vec2(0.);     // the id adjusted for the actual location of the cell
            
            /*
            Here we see which shapes are in this cell and the surrounding
            cells (the shapes nearby) and draw their value for this pixel.
            Unfortunately we cannot increase the shape density
            while maintaining the vertical travel of the shapes
            without having shapes from far-away grid cells "come into"
            our grid cell and not being being drawn since we only check
            nearby cells for shapes.
            This introduces clipping on the shapes which can only be fixed by
            increasing the number of neighboring grid cells checked
            per iteration, which unfortunately hurts performance.
            We already need slightly more vertical grid cells with the
            default settings because the shapes were already traveling
            too far.
            */
            #if PRESERVE_VERTICAL_TRAVEL
            // I did a quick check at density ~30 with default size
            // with these start/end values but they aren't perfect
            const vec2 startValue = vec2(-1.-DENSITY/30.,-2.-DENSITY/14.),
                       endValue = vec2(1.+DENSITY/60.,1.+DENSITY/10.);
            #else
            const vec2 startValue = vec2(-1.,-2.),
                       endValue = vec2(1.);
            #endif
            for(float yCell=startValue.y; yCell <= endValue.y; yCell++) {
                for(float xCell=startValue.x; xCell <= endValue.x; xCell++) {
                    vec2 off = vec2(xCell,yCell);
                    cid = id+off;
                    vec2 origin = off+N22(cid);
                    
                    // big/random multipliers to spread out shape types
                    float shapeID = 400.*rand(cid)+2.526*cid.y;
                    
                    origin = sway(origin,vec2(0.),
                                  #if PRESERVE_VERTICAL_TRAVEL 
                                  DENSITY*
                                  #endif
                                  VERTICAL_TRAVEL,shapeID);
                    

                    // rotate and scale the coordinate system for the shape
                    // which we previously moved vertically based on time
                    vec2 pointRotated = 1./DENSITY*(origin-xy)*rotate(sin(SPEED_ROTATION*iTime-shapeID));
                    switch(int(mod(shapeID,4.))) {
                    case 0:
                    default:
                        col = mix(col,SHAPE_GRAY,
                                  X(pointRotated,SHAPE_SIZE,BLUR,ALPHA));
                        break;
                    case 1:
                        col = mix(col,SHAPE_GRAY,
                                  circle(pointRotated,SHAPE_SIZE,BLUR,ALPHA));
                        break;
                    case 2:
                        col = mix(col,SHAPE_GRAY,
                                  triangle(pointRotated,SHAPE_SIZE,
                                           EQUILATERAL_HEIGHT,
                                           BLUR,ALPHA));
                        break;
                    case 3:
                        col = mix(col,SHAPE_GRAY,
                                  square(pointRotated,SHAPE_SIZE,BLUR,ALPHA));
                        break;
                    }
                }
            }
            #else
            for(float i = 0.; i < SHAPE_AMOUNT; i++) {
                vec2 seed = vec2(i,i);
                vec2 cord = vec2(rand(seed),rand(-.5*seed));
                cord.x *= ASPECT_RATIO;
                vec2 xy = sway(uv,cord,VERTICAL_TRAVEL,i);
                switch(int(mod(i,4.))) {
                    case 0:
                        xy *= rotate(sin(SPEED_ROTATION*iTime-i));
                        col = mix(col,SHAPE_GRAY,
                                  X(xy,SHAPE_SIZE,BLUR,ALPHA));
                        break;
                    case 1:
                        col = mix(col,SHAPE_GRAY,
                                  circle(xy,SHAPE_SIZE,BLUR,ALPHA));
                        break;
                    case 2:
                        xy *= rotate(sin(SPEED_ROTATION*iTime-i));
                        col = mix(col,SHAPE_GRAY,
                                  triangle(xy,SHAPE_SIZE,
                                           EQUILATERAL_HEIGHT,
                                           BLUR,ALPHA));
                        break;
                    case 3:
                    default:
                        xy *= rotate(sin(SPEED_ROTATION*iTime-i));
                        col = mix(col,SHAPE_GRAY,
                                  square(xy,SHAPE_SIZE,BLUR,ALPHA));
                        break;
                }
            }
            #endif
            
            fragColor = vec4(col,1.0);
        }
        """
    }
    
    /// 将 UIColor 转为 GLSL `vec3(r,g,b)` 字面量
    /// 动态色（`UIColor(.dm, ...)` / `R.Color`）必须先按当前外观 resolve，再取 RGB。
    private static func glslVec3(_ color: UIColor) -> String {
        // 与 RomPatcherView 一致：用窗口真实外观，而不是 UITraitCollection.current
        // （模型层 / 非 view 上下文里 current 经常对不上，且直接 getRed 动态色会落到错误一侧）
        let resolved = color.forceStyle(UIDevice.isDarkMode ? .dark : .light)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "vec3(%.5f,%.5f,%.5f)", Double(r), Double(g), Double(b))
    }
    
    //trinketMage — colors injected at build time
    /// 生成 HarmonicSineWave GLSL
    /// - Parameters:
    ///   - backgroundColor: 底色（原版约 `vec3(0.9)` 近白）
    ///   - waveColor: 波纹高亮色（原版约 `vec3(1.0)`）
    static func harmonicSineWaveScript(
        backgroundColor: UIColor = UIColor(white: 0.9, alpha: 1),
        waveColor: UIColor = .white
    ) -> String {
        let backgroundVec = glslVec3(backgroundColor)
        let waveVec = glslVec3(waveColor)
        return """
        // Colors (injected from Swift)
        #define BACKGROUND_COLOR \(backgroundVec)
        #define WAVE_COLOR \(waveVec)

        void mainImage( out vec4 fragColor, in vec2 fragCoord )
        {
            vec2 uv = fragCoord / iResolution.x;
            uv.y *= 1.25;
            // Phase advances at constant rate (must not feed wavelength, or motion dies over time).
            float time = iTime * 0.000628;
            // Original used unbounded `time` in wavelength denominators (params*.y), so
            // frequency → 0 and the animation appeared to slow. Keep morph bounded instead.
            float morph = sin(time);
            
            vec3 params1 = vec3(
                20.0,
                100.0 + 12.5 * uv.y,
                (0.0)
            );
                
            vec3 params2 = vec3(
                0.03125 - 0.03125 * uv.y,
                0.125 - 0.0625 * -morph + 0.0625 * uv.y,
                0.0 
            );
                
            vec3 params3 = vec3(
                0.025 - 0.025 * uv.y * 4.,
                0.125 - 0.0125 * -morph + 0.25 * uv.y,
                0.01
            );
                
            vec3 params4 = vec3(
                0.25 - 0.025 * uv.y * 2.,
                1.125 - 0.125 * -morph + 1.0 * uv.y,
                1.0
            );
            
            uv.y += params1.x * sin(uv.x / params1.y + time) + params1.z + params2.x * cos(uv.x / params2.y);
            uv.y += params3.x * sin(uv.x / params3.y + time) + params3.z;
            uv.y += params4.x * sin(uv.x / params4.y + time) + params4.z;

            float ny = sin(mod(uv.y * 18., 1.0));
            
            float up = 1.0 - smoothstep(0.25, 1.0, ny);
            float down = smoothstep(0.0, 0.2, ny);
            
            // Original was grayscale * 0.1 + 0.9 == mix(0.9, 1.0, mask)
            float mask = up * down;
            fragColor = vec4(mix(BACKGROUND_COLOR, WAVE_COLOR, mask), 1.0);
        }
        """
    }
    
    //hahnzhu — colors injected from [UIColor]; layer rot computed once
    /// GradientFlow 默认四色（黄 / 深蓝 / 红 / 蓝）
    private static let gradientFlowDefaultColors: [UIColor] = [
        UIColor(red: 0.957, green: 0.804, blue: 0.623, alpha: 1),
        UIColor(red: 0.192, green: 0.384, blue: 0.933, alpha: 1),
        UIColor(red: 0.910, green: 0.510, blue: 0.800, alpha: 1),
        UIColor(red: 0.350, green: 0.710, blue: 0.953, alpha: 1)
    ]
    
    /// 生成 GradientFlow GLSL
    /// - Parameter colors: 最多取前 4 个，依次对应 layer1 两端与 layer2 两端；不足 4 个时循环补齐，空数组用默认配色
    static func gradientFlowScript(colors: [UIColor] = []) -> String {
        let palette = gradientFlowResolvedColors(colors)
        let c0 = glslVec3(palette[0])
        let c1 = glslVec3(palette[1])
        let c2 = glslVec3(palette[2])
        let c3 = glslVec3(palette[3])
        return """
        #define S(a,b,t) smoothstep(a,b,t)

        // Colors (injected from Swift)
        #define COLOR_0 \(c0)
        #define COLOR_1 \(c1)
        #define COLOR_2 \(c2)
        #define COLOR_3 \(c3)

        mat2 Rot(float a)
        {
            float s = sin(a);
            float c = cos(a);
            return mat2(c, -s, s, c);
        }


        // Created by inigo quilez - iq/2014
        // License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
        vec2 hash( vec2 p )
        {
            p = vec2( dot(p,vec2(2127.1,81.17)), dot(p,vec2(1269.5,283.37)) );
            return fract(sin(p)*43758.5453);
        }

        float noise( in vec2 p )
        {
            vec2 i = floor( p );
            vec2 f = fract( p );
            
            vec2 u = f*f*(3.0-2.0*f);

            float n = mix( mix( dot( -1.0+2.0*hash( i + vec2(0.0,0.0) ), f - vec2(0.0,0.0) ), 
                                dot( -1.0+2.0*hash( i + vec2(1.0,0.0) ), f - vec2(1.0,0.0) ), u.x),
                           mix( dot( -1.0+2.0*hash( i + vec2(0.0,1.0) ), f - vec2(0.0,1.0) ), 
                                dot( -1.0+2.0*hash( i + vec2(1.0,1.0) ), f - vec2(1.0,1.0) ), u.x), u.y);
            return 0.5 + 0.5*n;
        }


        void mainImage( out vec4 fragColor, in vec2 fragCoord )
        {
            vec2 uv = fragCoord/iResolution.xy;
            float ratio = iResolution.x / iResolution.y;

            vec2 tuv = uv;
            tuv -= .5;

            // rotate with Noise
            float degree = noise(vec2(iTime*.1, tuv.x*tuv.y));

            tuv.y *= 1./ratio;
            tuv *= Rot(radians((degree-.5)*720.+180.));
            tuv.y *= ratio;

            
            // Wave warp with sin
            float frequency = 5.;
            float amplitude = 30.;
            float speed = iTime * 2.;
            tuv.x += sin(tuv.y*frequency+speed)/amplitude;
            tuv.y += sin(tuv.x*frequency*1.5+speed)/(amplitude*.5);
            
            
            // draw the image (shared -5° sample axis)
            float axis = (tuv * Rot(radians(-5.))).x;
            vec3 layer1 = mix(COLOR_0, COLOR_1, S(-.3, .2, axis));
            vec3 layer2 = mix(COLOR_2, COLOR_3, S(-.3, .2, axis));
            
            vec3 finalComp = mix(layer1, layer2, S(.5, -.3, tuv.y));
            
            fragColor = vec4(finalComp,1.0);
        }
        """
    }
    
    /// 将传入颜色补齐为 4 个（空则默认；不足则循环）
    static func gradientFlowResolvedColors(_ colors: [UIColor]) -> [UIColor] {
        let source = colors.isEmpty ? gradientFlowDefaultColors : colors
        return (0..<4).map { source[$0 % source.count] }
    }
    
    //ejonghyuck — 7 waves -> 5; colors injected
    /// 生成 PS3HomeBackground GLSL
    /// - Parameters:
    ///   - top: 背景渐变顶部色
    ///   - bottom: 背景渐变底部色
    ///   - wave: 波纹叠加色（原版灰 `vec3(0.3)`）
    static func pS3HomeBackgroundScript(
        top: UIColor = UIColor(red: 0.318, green: 0.831, blue: 1.0, alpha: 1),
        bottom: UIColor = UIColor(red: 0.094, green: 0.141, blue: 0.424, alpha: 1),
        wave: UIColor = UIColor(white: 0.3, alpha: 1)
    ) -> String {
        let topVec = glslVec3(top)
        let bottomVec = glslVec3(bottom)
        let waveVec = glslVec3(wave)
        return """
        // Colors (injected from Swift)
        #define TOP_COLOR \(topVec)
        #define BOTTOM_COLOR \(bottomVec)
        #define WAVE_COLOR \(waveVec)

        const float widthFactor = 1.5;

        vec3 calcSine(vec2 uv, float speed,
                      float frequency, float amplitude, float shift, float offset,
                      vec3 color, float width, float exponent, bool dir)
        {
            float angle = iTime * speed * frequency * -1.0 + (shift + uv.x) * 2.0;
            float y = sin(angle) * amplitude + offset;
            float diffY = y - uv.y;
            float dsqr = abs(diffY);
            // Soften one side of the ribbon
            if ((diffY > 0.0) == dir) {
                dsqr *= 4.0;
            }
            float scale = pow(smoothstep(width * widthFactor, 0.0, dsqr), exponent);
            return color * scale;
        }

        void mainImage( out vec4 fragColor, in vec2 fragCoord )
        {
            vec2 uv = fragCoord.xy / iResolution.xy;
            vec3 color = mix(BOTTOM_COLOR, TOP_COLOR, uv.y);

            // Mid ribbons (dir=false)
            color += calcSine(uv, 0.2, 0.20, 0.2, 0.0, 0.5, WAVE_COLOR, 0.1, 15.0, false);
            color += calcSine(uv, 0.4, 0.40, 0.15, 0.0, 0.5, WAVE_COLOR, 0.1, 17.0, false);

            // Upper ribbons (dir=true)
            color += calcSine(uv, 0.1, 0.26, 0.07, 0.0, 0.3, WAVE_COLOR, 0.1, 17.0, true);
            color += calcSine(uv, 0.3, 0.36, 0.07, 0.0, 0.3, WAVE_COLOR, 0.1, 17.0, true);
            color += calcSine(uv, 0.5, 0.46, 0.07, 0.0, 0.3, WAVE_COLOR, 0.05, 23.0, true);

            fragColor = vec4(color, 1.0);
        }
        """
    }
    
    /// 生成 PSPXMB GLSL
    /// - Parameters:
    ///   - backgroundBottom: 背景渐变底部（原浅绿）
    ///   - backgroundTop: 背景渐变顶部（原深绿）
    ///   - waveTop / waveBottom: 波浪填充渐变
    ///   - highlight: 波峰高光与径向光（原白）
    static func pSPXMBScript(
        backgroundBottom: UIColor = UIColor(red: 0.3, green: 0.95, blue: 0.5, alpha: 1),
        backgroundTop: UIColor = UIColor(red: 0.1, green: 0.6, blue: 0.24, alpha: 1),
        waveTop: UIColor = UIColor(red: 0.45, green: 1.0, blue: 0.5, alpha: 1),
        waveBottom: UIColor = UIColor(red: 0.3, green: 0.9, blue: 0.3, alpha: 1),
        highlight: UIColor = .white
    ) -> String {
        let bgBottomVec = glslVec3(backgroundBottom)
        let bgTopVec = glslVec3(backgroundTop)
        let waveTopVec = glslVec3(waveTop)
        let waveBottomVec = glslVec3(waveBottom)
        let highlightVec = glslVec3(highlight)
        return """
        // Colors (injected from Swift)
        #define BG_BOTTOM \(bgBottomVec)
        #define BG_TOP \(bgTopVec)
        #define WAVE_TOP \(waveTopVec)
        #define WAVE_BOTTOM \(waveBottomVec)
        #define HIGHLIGHT_COLOR \(highlightVec)

        void mainImage(out vec4 fragColor, in vec2 fragCoord)
        {
            vec2 uv = fragCoord.xy / iResolution.xy;

            // === PARAMETERS ===
            const float baseSpeed     = 0.0002;
            const float maxSpeed      = 0.0005;
            const float spacing       = 0.03;
            const float waveFrequency = 4.0;
            const float baseY         = 0.35;
            const float baseAmplitude = 0.03;
            const float maxAmplitude  = 0.08;

            // === BACKGROUND GRADIENT ===
            vec3 color = mix(BG_BOTTOM, BG_TOP, uv.y);

            // === WAVES (unrolled 2; per-wave hashes are compile-time constants) ===
            // i = 0
            {
                float phase = 0.0;
                float ampFreq = 0.8;
                float ampPhase = 0.0;
                float t = 0.5 + 0.5 * sin(iTime * ampFreq + ampPhase);
                float amplitude = mix(baseAmplitude, maxAmplitude, t);
                float baseSpeedPerWave = baseSpeed;
                float speedOsc = 0.25 + 0.25 * sin(iTime * 0.5 + phase);
                float speed = baseSpeedPerWave * (1.0 + speedOsc * 0.2);
                float wave = sin((uv.x - iTime * speed) * waveFrequency + phase) * amplitude;
                float waveY = baseY + wave;
                float mask = smoothstep(waveY + 0.001, waveY - 0.001, uv.y);
                float gradFactor = clamp((waveY - uv.y) / max(waveY, 1e-3), 0.0, 1.0);
                vec3 waveColor = mix(WAVE_TOP, WAVE_BOTTOM, gradFactor);
                color = mix(color, waveColor, 0.65 * mask);
                float lightY = waveY + 0.001;
                float lightW = 0.0025;
                float lightMask = smoothstep(lightY - lightW, lightY, uv.y)
                                * (1.0 - smoothstep(lightY, lightY + lightW, uv.y));
                color = mix(color, HIGHLIGHT_COLOR, lightMask * 0.08);
            }
            // i = 1
            {
                float offset = spacing;
                float phase = 1.5;
                float ampFreq = 0.8 + 0.3 * fract(sin(78.233) * 43758.5453);
                float ampPhase = fract(sin(15.873) * 23421.1234) * 6.2831;
                float t = 0.5 + 0.5 * sin(iTime * ampFreq + ampPhase);
                float amplitude = mix(baseAmplitude, maxAmplitude, t);
                float baseSpeedPerWave = mix(baseSpeed, maxSpeed, fract(sin(91.123) * 5341.728));
                float speedOsc = 0.25 + 0.25 * sin(iTime * 0.5 + phase);
                float speed = baseSpeedPerWave * (1.0 + speedOsc * 0.2);
                float wave = sin((uv.x - iTime * speed) * waveFrequency + phase) * amplitude;
                float waveY = baseY + offset + wave;
                float mask = smoothstep(waveY + 0.001, waveY - 0.001, uv.y);
                float gradFactor = clamp((waveY - uv.y) / max(waveY, 1e-3), 0.0, 1.0);
                vec3 waveColor = mix(WAVE_TOP, WAVE_BOTTOM, gradFactor);
                color = mix(color, waveColor, 0.65 * mask);
                float lightY = waveY + 0.001;
                float lightW = 0.0025;
                float lightMask = smoothstep(lightY - lightW, lightY, uv.y)
                                * (1.0 - smoothstep(lightY, lightY + lightW, uv.y));
                color = mix(color, HIGHLIGHT_COLOR, lightMask * 0.08);
            }

            // === RADIAL LIGHT OVERLAY ===
            float dist = distance(uv, vec2(1.0, 0.85));
            float glow = pow(1.0 - smoothstep(0.0, 0.75, dist), 1.5) * 0.2;
            color = mix(color, HIGHLIGHT_COLOR, glow);

            fragColor = vec4(color, 1.0);
        }
        """
    }
    
    // Ping — mobile: drop iChannel0 (dummy black), fewer hills/clouds, cheaper cloud SDF
    static let PaperScroll = """
        const vec3 c0 = vec3(.042,0.530,0.159);
        const vec3 c1 = vec3(.142,0.630,0.259);
        const vec3 c2 = vec3(0.242,0.730, 0.359);
        const vec3 c3 = vec3(0.342,0.830,0.459);
        const vec3 c4 = vec3(0.442,0.930,0.559);
        const vec3 c5 = vec3(1);
        const vec3 c6 = vec3(0.95, 0.95 ,1.0);
        const vec3 c7 = vec3(0.9, 0.9,1.0);

        #define GRND1 min(length(fract(op)*vec2(1, 3) - vec2(0.5,0.18)) - 0.3, length(fract(op+vec2(0.5, 0))*vec2(1, 2) - vec2(0.5,0.09)) - 0.35)
        #define GRND2 min(length(fract(op)*vec2(1.2, 2.5) - vec2(0.5,0.45)) - 0.4, length(fract(op+vec2(0.65, 0))*vec2(1, 1.4) - vec2(0.5,0.25)) - 0.35)
        #define GRND3 min(length(fract(op)-vec2(0.5,0.3))-0.35, length(fract(op+vec2(0.5, 0))-vec2(0.5,0.25))-0.3)
        #define GRND5 min(length(fract(op)-vec2(0.5,0.2))-0.5, length(fract(op+vec2(0.5, 0))-vec2(0.5,0.2))-0.5)

        vec3 ground(in vec2 u, in vec3 c, in float shadow_pos)
        {
            if(u.y >= 0.4) return c;
            const float b = 0.005;
            vec2 op = u*2.0;
            op.x += iTime*0.05;
            c = mix(c, c0*0.98, smoothstep(b*5.0, -b*5.0, GRND5));

            op = vec2(u.x*4.0 + iTime*0.2 - shadow_pos, u.y*3.0-0.2);
            c = mix(c, c*0.9, smoothstep(b*10.0, -b*10.0, GRND3));
            op.x += shadow_pos;
            c = mix(c, c2*0.98, smoothstep(b*0.5, -b*0.5, GRND3));

            op = vec2(u.x*5.0 + iTime*0.4 - shadow_pos, u.y*2.0);
            c = mix(c, c*0.82, smoothstep(b*20.0, -b*20.0, GRND2));
            op.x += shadow_pos;
            c = mix(c, c3*0.98, smoothstep(b*3.0, -b*3.0, GRND2));

            op = vec2(u.x*8.0 + iTime - shadow_pos, u.y*2.0+0.02);
            c = mix(c, c*0.75, smoothstep(b*30.0, -b*30.0, GRND1));
            op += vec2(shadow_pos, -0.02);
            c = mix(c, c4*0.96, smoothstep(b*5.0, -b*5.0, GRND1));
            return c;
        }

        float sdLine(in vec2 p, in vec2 a, in vec2 b)
        {
            vec2 pa = p-a, ba = b-a;
            float h = clamp(dot(pa,ba)/dot(ba,ba), 0.0, 1.0);
            return length(pa - ba*h);
        }

        // 2-circle blob instead of 3; skip separate thread-shadow pass
        vec3 cloud(in vec2 u, in vec2 p, in float iscale, in vec3 c, const in vec3 cloud_color, in vec2 shadow_pos, in float shadow_factor, in float blur, in float shadow_blur)
        {
            u *= iscale;
            p *= iscale;
            vec2 st = u - p - shadow_pos;
            float d = min(length(st) - 0.07, length(st - vec2(0.06, 0)) - 0.055);
            c = mix(c, c*shadow_factor, smoothstep(shadow_blur, -shadow_blur, d));
            st += shadow_pos;
            d = min(length(st) - 0.07, length(st - vec2(0.06, 0)) - 0.055);
            c = mix(c, cloud_color*0.98, smoothstep(blur, -blur, d));
            float thr = blur / (iscale*iscale);
            c = mix(c, cloud_color*0.65, smoothstep(thr, -thr*0.5, sdLine(u, p + vec2(0,0.065), vec2(p.x, iscale))));
            return c;
        }

        void mainImage(out vec4 fragColor, in vec2 fragCoord)
        {
            vec2 uv = fragCoord/iResolution.xy;
            uv.x *= 4.0/3.0;
            float d = length(uv-vec2(0.25,0.5));
            vec3 c = mix(vec3(.4,0.4,.8), vec3(0.55,0.8,0.8), smoothstep(1.7, 0., d));
            float shadow_pos = -smoothstep(1.0, 0.0, uv.x)*0.06 - 0.1;
            c = ground(uv, c, shadow_pos);

            // 6 clouds (was 10): keep far/mid/near variety
            vec2 np = vec2(1.4-fract((iTime+50.0)*0.005)*1.5, 0.8);
            c = cloud(uv, np, 2.0, c, c7, vec2(shadow_pos, -0.1)*0.2, 0.8, 0.01, 0.03);
            np = vec2(1.4-fract(iTime*0.0055)*1.5, 0.75 + sin(iTime*0.1)*0.01);
            c = cloud(uv, np, 2.0, c, c7, vec2(shadow_pos, -0.1)*0.2, 0.8, 0.01, 0.03);
            np = vec2(1.41-fract((iTime+75.0)*0.007)*1.5, 0.88 + sin(iTime*0.05)*0.01);
            c = cloud(uv, np, 1.5, c, c6, vec2(shadow_pos, -0.1)*0.2, 0.8, 0.005, 0.04);
            np = vec2(1.41-fract((iTime+35.0)*0.0067)*1.5, 0.82 + sin(0.9+iTime*0.035)*0.012);
            c = cloud(uv, np, 1.5, c, c6, vec2(shadow_pos, -0.1)*0.2, 0.8, 0.005, 0.04);
            np = vec2(1.50-fract(iTime*0.011)*1.75, 0.85 + sin(iTime*0.2)*0.025);
            c = cloud(uv, np, 1.0, c, c5, vec2(shadow_pos, -0.1)*0.2, 0.8, 0.002, 0.04);
            np = vec2(1.50-fract((iTime+35.0)*0.009)*1.75, 0.8 + sin(0.5+iTime*0.05)*0.025);
            c = cloud(uv, np, 1.0, c, c5, vec2(shadow_pos, -0.1)*0.2, 0.8, 0.002, 0.04);

            fragColor = vec4(c,1.0);
        }
        """
    
    // Synthwave — analytical AA (no 4x MSAA); soft palm/triangle/sun edges
    static let SynthwaveSunset = """
        #define NH 4
        #define NV 8
        #define PI 3.14159265

        float prm(float a, float b, float x) {
            return clamp((x - a) / (b - a), 0.0, 1.0);
        }

        float par(float x) {
            return 1.0 - pow(2.0 * x - 1.0, 2.0);
        }

        float segment_df(vec2 uv, vec2 p0, vec2 p1) {
            vec2 ba = p1 - p0;
            float t = clamp(dot(uv - p0, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
            return length(uv - (p0 + t * ba));
        }

        float segment_side(vec2 p0, vec2 p1, vec2 p2) {
            return (p0.x - p2.x) * (p1.y - p2.y) - (p1.x - p2.x) * (p0.y - p2.y);
        }

        bool triangle_in(vec2 uv, vec2 p0, vec2 p1, vec2 p2) {
            float d0 = segment_side(uv, p0, p1);
            float d1 = segment_side(uv, p1, p2);
            float d2 = segment_side(uv, p2, p0);
            return !(((d0 < 0.0) || (d1 < 0.0) || (d2 < 0.0)) && ((d0 > 0.0) || (d1 > 0.0) || (d2 > 0.0)));
        }

        float triangle_sdf(vec2 uv, vec2 p0, vec2 p1, vec2 p2) {
            float d = min(segment_df(uv, p0, p1), min(segment_df(uv, p1, p2), segment_df(uv, p2, p0)));
            return triangle_in(uv, p0, p1, p2) ? -d : d;
        }

        float sun_sdf(vec2 uv) {
            float t = mod(iTime, 4.0) / 4.0;
            float lo[7] = float[7](0.2, 0.03, -0.14, -0.31, -0.48, -0.65, -0.8);
            float hi[7] = float[7](0.2, 0.05, -0.1, -0.25, -0.4, -0.55, -0.7);
            float bands_sdf = 10.0;
            for (int i = 0; i < 6; i++) {
                float low = mix(lo[i+1], lo[i], t);
                float high = mix(hi[i+1], hi[i], t);
                bands_sdf = min(bands_sdf, max(uv.y-high, low-uv.y));
            }
            return max(length(uv) - 0.7, -bands_sdf);
        }

        float sq(float x) { return x * x; }

        // Soft palm coverage 0..1 instead of hard bool
        float palm_mask(vec2 uv) {
            const float ah[NH] = float[NH](0.1, 0.25, 1.5, 2.5);
            const float bh[NH] = float[NH](0.2, 0.75, -0.37, -0.17);
            const float ch[NH] = float[NH](-0.17, 0.07, -0.147, 0.255);
            const float dh[NH] = float[NH](-0.8, -0.8, 0.3, 0.1);
            const float eh[NH] = float[NH](0.3, 0.1, 0.57, 0.37);
            const float fh[NH] = float[NH](-1.7, -1.7, 0.3, 0.1);
            const float gh[NH] = float[NH](0.3, 0.1, 0.57, 0.37);
            const float th0[NH] = float[NH](0.01, 0.01, 0.005, 0.005);
            const float th1[NH] = float[NH](0.03, 0.03, 0.03, 0.03);

            float aa = max(fwidth(uv.x), 0.002) * 1.5;
            float m = 0.0;
            for (int i = 0; i < NH; i++) {
                float halfW = mix(th0[i], th1[i], par(prm(fh[i], gh[i], uv.y)));
                float h_dist = abs(uv.x - (ah[i] * sq(uv.y + bh[i]) + ch[i]));
                float along = smoothstep(dh[i]-aa, dh[i]+aa, uv.y) * smoothstep(eh[i]+aa, eh[i]-aa, uv.y);
                m = max(m, (1.0 - smoothstep(halfW - aa, halfW + aa, h_dist)) * along);
            }

            const float av[NV] = float[NV](-2.7, -1.6, -3.5, -2.0, -2.0, -1.6, -3.0, -2.5);
            const float bv[NV] = float[NV](0.17, 0.3, 0.35, -0.02, -0.225, -0.095, -0.045, -0.4);
            const float cv[NV] = float[NV](0.3, 0.35, 0.46, 0.35, 0.1, 0.15, 0.25, 0.15);
            const float dv[NV] = float[NV](-0.5, -0.65, -0.5, -0.15, -0.155, -0.255, -0.1, 0.26);
            const float ev[NV] = float[NV](-0.14, -0.14, -0.14, 0.25, 0.255, 0.255, 0.255, 0.645);

            for (int i = 0; i < NV; i++) {
                float halfW = mix(0.005, 0.04, par(prm(dv[i], ev[i], uv.x)));
                float v_dist = abs(uv.y - (av[i] * sq(uv.x + bv[i]) + cv[i]));
                float along = smoothstep(dv[i]-aa, dv[i]+aa, uv.x) * smoothstep(ev[i]+aa, ev[i]-aa, uv.x);
                m = max(m, (1.0 - smoothstep(halfW - aa, halfW + aa, v_dist)) * along);
            }
            return clamp(m, 0.0, 1.0);
        }

        mat2 rotation_mat(float alpha) {
            float c = cos(alpha), s = sin(alpha);
            return mat2(c, s, -s, c);
        }

        // Soft fill / stroke from signed distance
        void softShape(inout vec3 col, float sdf, vec3 fill, vec3 stroke, float strokeW, float px) {
            float fillA = 1.0 - smoothstep(-px, px, sdf);
            float strokeA = smoothstep(strokeW + px, strokeW - px, abs(sdf)) * (1.0 - fillA);
            col = mix(col, fill, fillA);
            col = mix(col, stroke, strokeA);
        }

        void mainImage(out vec4 fragColor, in vec2 fragCoord)
        {
            vec2 uv = 2.0 * (fragCoord - iResolution.xy * 0.5) / iResolution.y;
            float px = max(fwidth(uv.x), 0.002) * 1.25;

            const vec3 BG = vec3(0.1, 0.1, 0.2);
            vec3 cyan = vec3(0.3, 0.85, 1);
            vec3 magenta = vec3(1, 0.1, 1);
            float t = sin(0.3 * cos(0.2 * iTime) * uv.x + uv.y + 1.0 + 0.15 * cos(0.3 * iTime));
            vec3 cm = mix(cyan, magenta, t*t);
            vec3 mc = mix(magenta, cyan, t*t);

            vec2 a = vec2(0, -0.9);
            vec2 b = vec2(-1.0, 0.4);
            vec2 c = vec2(1.1, 0.6);
            float alpha = 0.25 * cos(0.5 * iTime);
            float gamma = -0.1 + 0.2 * cos(PI + 0.5 * iTime);
            float beta = (alpha + gamma) * 0.5;
            mat2 alpha_mat = rotation_mat(alpha);
            mat2 beta_mat = rotation_mat(beta);
            mat2 gamma_mat = rotation_mat(gamma);

            vec2 t0a = alpha_mat * a;
            vec2 t0b = alpha_mat * b;
            vec2 t0c = alpha_mat * c;
            vec2 t1b = mix(t0a, t0b, 3.0);
            vec2 t1c = mix(t0a, t0c, 3.0);
            vec2 t2a = beta_mat * a, t2b = beta_mat * b, t2c = beta_mat * c;
            vec2 t3a = gamma_mat * a, t3b = gamma_mat * b, t3c = gamma_mat * c;

            float sun = sun_sdf(uv);
            float tri0 = triangle_sdf(uv, t0a, t0b, t0c);
            float tri1 = triangle_sdf(uv, t0a, t1b, t1c);
            float tri2 = triangle_sdf(uv, t2a, t2b, t2c);
            float tri3 = triangle_sdf(uv, t3a, t3b, t3c);

            vec3 col = BG;
            softShape(col, tri3, vec3(0.0), mc, 0.01, px);
            softShape(col, tri2, mc, mc, 0.0, px);
            softShape(col, tri0, vec3(0.0), mc, 0.01, px);

            float tri1Fill = 1.0 - smoothstep(-px, px, tri1);
            if (tri1Fill > 0.001) {
                vec3 sunCol = mix(cm, col, smoothstep(-px, px, sun));
                col = mix(col, sunCol, tri1Fill);
                col = mix(col, vec3(0.0), palm_mask(uv) * tri1Fill);
            }
            fragColor = vec4(col, 1.0);
        }
        """
    
    // Voronoi — restore original site layout & edge look; POINTS=12 (no extra cost)
    static let MellowVoronoi = """
        const int POINTS = 12;
        const float WAVE_OFFSET = 12000.0;
        const float SPEED = 1.0 / 12.0;
        const float COLOR_SPEED = 1.0 / 4.0;
        const float BRIGHTNESS = 1.2;

        void voronoi(vec2 uv, inout vec3 col)
        {
            vec3 voronoi = vec3(0.0);
            float time = (iTime + WAVE_OFFSET)*SPEED;
            float bestDistance = 999.0;
            float lastBestDistance = bestDistance;
            for (int i = 0; i < POINTS; i++)
            {
                float fi = float(i);
                // Original layout: x = sin(fi); rows via i/10
                vec2 p = vec2(sin(fi),
                              -0.05 + 0.15 * float(i / 10) + cos(fi + time * cos(uv.x * 0.025)));
                float d = distance(uv, p);
                if (d < bestDistance)
                {
                    lastBestDistance = bestDistance;
                    bestDistance = d;
                    voronoi.x = p.x;
                    voronoi.yz = vec2(p.x * 0.4 + p.y, p.y) * vec2(0.9, 0.87);
                }
            }
            float edge = 1.0 - abs(bestDistance - lastBestDistance);
            col *= 0.68 + 0.19 * voronoi;
            // Slightly wider smoothstep than original → softer edges at low res, same ALU
            col += smoothstep(0.97, 1.06, edge) * 0.9;
            col += smoothstep(0.93, 1.02, edge) * 0.1 * col;
            col += voronoi * 0.1 * smoothstep(0.45, 1.0, edge);
        }

        void mainImage(out vec4 fragColor, in vec2 fragCoord)
        {
            vec2 uv = fragCoord/iResolution.xy;
            vec3 col = 0.5 + 0.5*cos(iTime*COLOR_SPEED+uv.xyx+vec3(0,2,4));
            voronoi(uv * 4.0 - 1.0, col);
            fragColor = vec4(col,1.0)*BRIGHTNESS;
        }
        """
}
