#version 100

precision mediump float;

// Input vertex attributes (from vertex shader)
varying vec2 fragTexCoord;
varying vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// NOTE: Add here your custom variables
uniform int renderWidth, renderHeight;

const int kernelRadius = 20;
const int kernelSize = 2 * kernelRadius + 1;

float gaussian(float x, float mu, float sigma) {
    float a = ( x - mu ) / sigma;
    return exp( -0.5 * a * a );
}

void main()
{
    // create kernal
    // float kernel[kernelSize * kernelSize];
    // float sigma = float(kernelRadius)/2.0;
    // float sum = 0.0;
    // // compute values
    // for (int row = 0; row < kernelSize; row++) {
    //     for (int col = 0; col < kernelSize; col++) {
    //         float x = gaussian(float(row), float(kernelRadius), sigma)
    //                 * gaussian(float(col), float(kernelRadius), sigma);
    //         kernel[row * kernelSize + col] = x;
    //         sum += x;
    //     }
    // }
    // // normalize
    // for (int row = 0; row < kernelSize; row++)
    //     for (int col = 0; col < kernelSize; col++)
    //         kernel[row * kernelSize + col] /= sum;

    // calculate the pixel    
    vec4 col = vec4(0);
    for (int dy = -kernelRadius; dy < kernelRadius; dy++) {
        for (int dx = -kernelRadius; dx < kernelRadius; dx++) {
            float x = (fragTexCoord.x * float(renderWidth) + float(dx)) / float(renderWidth);
            float y = (fragTexCoord.y * float(renderHeight) + float(dy)) / float(renderHeight);
            int kx = dx + kernelRadius;
            int ky = dy + kernelRadius;
            col += texture2D(texture0, vec2(x, y)); // * kernel[ky * kernelSize + kx];
        }
    }
    col /= float(kernelSize * kernelSize);

    gl_FragColor = col * colDiffuse;
}
