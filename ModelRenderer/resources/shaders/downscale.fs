#version 100

precision mediump float;

// Input vertex attributes (from vertex shader)
varying vec2 fragTexCoord;
varying vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// NOTE: Add here your custom variables
uniform int width;
uniform int height;
uniform vec2 resolution;

void main()
{
    vec2 downscaledUV = floor(fragTexCoord * resolution) / resolution;
    
    vec4 texelColor = texture2D(texture0, downscaledUV);

    gl_FragColor = texelColor*colDiffuse;
}
