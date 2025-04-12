varying vec2 vUv;
uniform float delta;
uniform vec4 resolution;
uniform vec2 mouse;

// 7 bits: 127 for the number 8
struct TwoDigitSegment { 
	lowp int tens; 
	lowp int ones; 
};

uniform TwoDigitSegment seconds;
uniform TwoDigitSegment minutes;
uniform TwoDigitSegment hours;


void main()
{
    vUv = uv;
    gl_Position = vec4(position, 1.0);
}