varying lowp vec4 fragmentColor;
uniform sampler2D texture;
varying lowp vec2 texCoordVar;       // fragment texture coordinate varying

void main()
{
    gl_FragColor =  texture2D( texture, texCoordVar);
}
