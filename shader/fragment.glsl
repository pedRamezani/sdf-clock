precision highp float;

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

// raymarching
const int MAXITERATION = 100;

// camera
const lowp float CAMERAZ = 5.0;

// segments
const lowp vec2 SEGMENTS[14] = vec2[14](
    vec2(-1.0,  1.0), vec2( 1.0,  1.0),  // top
    vec2(-1.0,  1.0), vec2(-1.0,  0.0),  // top-left
    vec2( 1.0,  1.0), vec2( 1.0,  0.0),  // top-right
    vec2(-1.0,  0.0), vec2( 1.0,  0.0),  // middle
    vec2(-1.0,  0.0), vec2(-1.0, -1.0),  // bottom-left
    vec2( 1.0,  0.0), vec2( 1.0, -1.0),  // bottom-right
    vec2(-1.0, -1.0), vec2( 1.0, -1.0)   // bottom
);

bool getSegmentActive( lowp int segmentData, int index ) {
    return (segmentData & (1 << index)) != 0;
}

// rotation
const float PI = 3.141592653589793238;

mat4 rotationMatrix( vec3 axis, float angle )
{
    axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;

    return mat4(oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,  0.0,
                oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,  0.0,
                oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c,           0.0,
                0.0,                                0.0,                                0.0,                                1.0);
}

vec3 rotate( vec3 v, vec3 axis, float angle )
{
	mat4 m = rotationMatrix(axis, angle);
	return (m * vec4(v, 1.0)).xyz;
}

// cubic polynomial
float smin( float a, float b, float k) 
{
    k *= 6.0;
    float h = max( k-abs(a-b), 0.0 )/k;
    return min(a,b) - h*h*h*k*(1.0/6.0);
}

// 3D SDFs
float boxSDF( vec3 p, vec3 b ) 
{
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float capsuleSDF( vec3 p, vec3 a, vec3 b, float r ) 
{
  vec3 pa = p - a, ba = b - a;
  float h = clamp(dot(pa,ba)/dot(ba,ba), 0.0, 1.0);
  return length(pa - ba*h) - r;
}

float sphereSDF( vec3 p, float r )
{
    return length(p) - r;
}

float segmentSDF( vec3 p, lowp int activeSegments, float len, float radius )
{
    float value;
    bool firstSegmentDrawn = false;
    for ( int i = 0; i < 7; i++ ) 
    {
        if ( getSegmentActive(activeSegments, i) )
        {
            vec2 start = SEGMENTS[i * 2] * vec2(len, len*2.0);
            vec2 end   = SEGMENTS[i * 2 + 1] * vec2(len, len*2.0);
            float capsule = capsuleSDF(
                p, 
                vec3(start, 0.0), 
                vec3(end, 0.0), 
                radius
            );
            
            if ( firstSegmentDrawn )
            {
                value = min(capsule, value);
            }
            else 
            {
                value = capsule;
                firstSegmentDrawn = true;
            }
        }
    }

    return value;
}

float segmentPairSDF( vec3 p, lowp int activeFirstSegments, lowp int activeSecondSegments, float len )
{
    return min(
        segmentSDF(p - vec3(-len * 1.5, 0.0, 0.0), activeFirstSegments, len, len * 0.3),
        segmentSDF(p - vec3(len * 1.5, 0.0, 0.0), activeSecondSegments, len, len * 0.3)
    );
}


float sdf( vec3 p )
{
    float side = min(resolution.z, resolution.w) * 0.1;

    float hourSegments = segmentPairSDF(
        p - vec3(0.0, 3.0 * 2.0 * side * CAMERAZ, 0.0), 
        hours.tens, 
        hours.ones, 
        side * CAMERAZ
    );

    float minuteSegments = segmentPairSDF(
        p, 
        minutes.tens, 
        minutes.ones,
        side * CAMERAZ
    );
    
    float secondSegments = segmentPairSDF(
        p - vec3(0.0, -3.0 * 2.0 * side * CAMERAZ, 0.0), 
        seconds.tens, 
        seconds.ones, 
        side * CAMERAZ
    );

    float value = min(
        hourSegments,
        min(
            minuteSegments,
            secondSegments
        )
    );

    // float mouse = sphereSDF(p - vec3(mouse * resolution.zw * CAMERAZ, 0.0), side * CAMERAZ * 0.75);
    vec3 pt = rotate(p - vec3(mouse * resolution.zw * CAMERAZ, 0.0), vec3(1.0), delta);
    float mouse = boxSDF(pt, vec3(side * CAMERAZ * 0.75));

    return smin(mouse, value, side * CAMERAZ * 0.25);
}


vec3 calcNormal( in vec3 p )
{
    // Regular central differentiation method with 6 calls
    // const float h = 0.0001;
    // return normalize(vec3(
    //     sdf(p + vec3(h, 0.0, 0.0)) - sdf(p - vec3(h, 0.0, 0.0)),
    //     sdf(p + vec3(0.0, h, 0.0)) - sdf(p - vec3(0.0, h, 0.0)),
    //     sdf(p + vec3(0.0, 0.0, h)) - sdf(p - vec3(0.0, 0.0, h))
    // ));

    // Regular right-sided differentiation method with 3 calls
    // Optimised, but less accurate and with right-sided bias
    // const float h = 0.0001;
    // return normalize(vec3(
    //     sdf(p + vec3(h, 0.0, 0.0)),
    //     sdf(p + vec3(0.0, h, 0.0)),
    //     sdf(p + vec3(0.0, 0.0, h))
    // ));

    // Tetrahedron differentiation method with 4 calls
    const float h = 0.0001;
    const vec2 k = vec2(1,-1);
    return normalize( k.xyy * sdf( p + k.xyy*h ) + 
                      k.yyx * sdf( p + k.yyx*h ) + 
                      k.yxy * sdf( p + k.yxy*h ) + 
                      k.xxx * sdf( p + k.xxx*h ) );
}

float rayMarch( vec3 rayOrigin, vec3 ray, float tmin, float tmax )
{
    float t = tmin;
    // estimated maximum needed distance optimised for performance
    // may need to be increased for other sdf configurations
    for ( int i = 0; i < MAXITERATION && t <= tmax; i++ ) 
    {
        vec3 p = rayOrigin + ray * t;
        float d = sdf(p);
        if (d < 0.001) return t;
        t += d;
    }
    return -1.0;
}

void main()
{
    lowp vec3 cameraPos = vec3(0.0, 0.0, CAMERAZ);
    
    vec3 ray = normalize(vec3((vUv - vec2(0.5)) * 2.0 * resolution.zw, -1));

    lowp vec3 color = vec3(1.0);

    float t = rayMarch(cameraPos, ray, 0.0, 2.0 * CAMERAZ);
    if ( t > 0.0 ) 
    {
        vec3 p = cameraPos + ray * t;
        vec3 normal = calcNormal(p);

        float fresnel = pow(1.0 + dot(ray, normal), 3.0);
        color = vec3(fresnel);
        gl_FragColor = vec4(color, 1.0);
    }
    else 
    {
        gl_FragColor = vec4(1.0);
    }
}