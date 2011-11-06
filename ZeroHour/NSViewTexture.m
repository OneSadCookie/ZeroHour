#import <Cocoa/Cocoa.h>
#import <OpenGL/gl.h>

#import "NSViewTexture.h"

void TexSubImageNSView(
    GLenum target,
    id     view,
    GLint  xoffset,
    GLint  yoffset)
{    
    NSSize size = [view bounds].size;
    
    unsigned width = size.width;
    unsigned height = size.height;

    // prior to 10.6 one could specify negative bytesPerRow to have the image
    // up the right way for OpenGL.  In 10.6, NSBitmapImageRep complains if
    // you try, so we're stuck with upside-down textures...
    unsigned char *buffer = calloc(width * height, 4);
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:&buffer
                      pixelsWide:width
                      pixelsHigh:height
                   bitsPerSample:8
                 samplesPerPixel:4
                        hasAlpha:YES
                        isPlanar:NO
                  colorSpaceName:NSDeviceRGBColorSpace
                     bytesPerRow:width * 4
                    bitsPerPixel:32];
    NSImage *image = [[NSImage alloc] init];
    [image addRepresentation:bitmap];
    
    // this is 10.4+-only, what about 10.3?
    [view cacheDisplayInRect:[view bounds] toBitmapImageRep:bitmap];
        
    glTexSubImage2D(
        target,
        0,
        xoffset,
        yoffset,
        width,
        height,
        GL_RGBA,
        GL_UNSIGNED_BYTE,
        buffer);
    
    free(buffer);
}

void TexImageNSView(
    GLenum target,
    id     view)
{    
    NSSize size = [view bounds].size;
    glTexImage2D(
        target,
        0,
        GL_RGBA,
        size.width,
        size.height,
        0,
        GL_RGBA,
        GL_UNSIGNED_BYTE,
        NULL);
    TexSubImageNSView(target, view, 0, 0);
}
