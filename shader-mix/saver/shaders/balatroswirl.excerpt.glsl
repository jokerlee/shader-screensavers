float new_pixel_angle = atan(uv.y, uv.x) + speed
    - SPIN_EASE*20.*(SPIN_AMOUNT*uv_len + (1. - SPIN_AMOUNT));
// ...
for (int i=0; i < 5; i++) {
    uv2 += sin(max(uv.x, uv.y)) + uv;
    uv  += 0.5*vec2(cos(5.1123314 + 0.353*uv2.y + speed*0.131121),
                    sin(uv2.x - 0.113*speed));
    uv  -= 1.0*cos(uv.x + uv.y) - 1.0*sin(uv.x*0.711 - uv.y);
}
float paint_res = min(2., max(0., length(uv)*(0.035)*contrast_mod));
