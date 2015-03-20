attribute vec4 position;
attribute vec4 color;
attribute vec2 texCoord;
attribute vec4 normal;

uniform mat4 modelView;                 // shader modelview matrix uniform
uniform mat4 projection;                // shader projection matrix uniform

varying vec4 fragmentColor;
varying vec2 texCoordVar;               // vertex texture coordinate varying

void main()
{
    vec4 p = modelView * position;
    gl_Position = projection * p;
    fragmentColor = color;
    texCoordVar = texCoord;
}