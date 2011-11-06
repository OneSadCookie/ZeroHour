#import <Carbon/Carbon.h>
#import <OpenGL/gl.h>
#import <OpenGL/glu.h>

#import "NSViewTexture.h"
#import "ZHGLView.h"

// this code structure is a terrible hack, please don't copy it.

#define BOX_SIZE 32.0f
#define SIM_RATE (1.0 / 120.0)
#define X_SPEED  800.0f

#define MIN_X (0.0f   + 0.5f * BOX_SIZE)
#define MAX_X (800.0f - 0.5f * BOX_SIZE)

#define MAX_SHOTS 10
#define SHOT_INTERVAL 0.25
#define SHOT_SPEED 1000.0f

#define MAX_ENEMIES 25
#define ENEMY_SPEED 25.0f
#define ENEMY_INTERVAL_DECREASE 0.01

NSString * const Letters = @"EEEEEEEEEEEEAAAAAAAAAIIIIIIIIIOOOOOOOONNNNNNRRRRRRTTTTTTLLLLSSSSUUUUDDDDGGGBBCCMMPPFFHHVVWWYYKJXQZ";

@implementation ZHGLView
{
    bool firstFrame;
    NSPoint playerPosition;
    NSTimeInterval lastFrameTime;
    bool movingLeft, movingRight;
    
    NSPoint shots[MAX_SHOTS];
    unsigned shotCount;
    NSTimeInterval timeSinceShot;
    bool shooting;
    
    bool bomb;
    
    struct {
        NSPoint position;
        unichar letter;
    } enemies[MAX_ENEMIES];
    unsigned enemyCount;
    NSTimeInterval timeSinceEnemy;
    NSTimeInterval enemyInterval;
    
    NSMutableString *word;
    
    NSTextView *wordView;
    GLuint wordTexture;
    GLuint textures[26];
}

- (void)awakeFromNib
{
    firstFrame = true;
    playerPosition = NSMakePoint(400.0, 0.5 * BOX_SIZE);
    lastFrameTime = [NSDate timeIntervalSinceReferenceDate];
    movingLeft = movingRight = false;
    
    shotCount = 0;
    enemyCount = 0;
    enemyInterval = 1.0;
    
    word = [NSMutableString string];
    
    [NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(draw) userInfo:nil repeats:true];
}

- (BOOL)acceptsFirstResponder { return true; }

- (void)keyDown:(NSEvent *)event
{
    switch ([event keyCode])
    {
    case kVK_LeftArrow:  movingLeft  = true;  break;
    case kVK_RightArrow: movingRight = true;  break;
    case kVK_Space:      shooting    = true;  break;
    case kVK_ANSI_B:     bomb        = true;  break;
    default:                                  break;
    }
}

- (void)keyUp:(NSEvent *)event
{
    switch ([event keyCode])
    {
    case kVK_LeftArrow:  movingLeft  = false; break;
    case kVK_RightArrow: movingRight = false; break;
    case kVK_Space:      shooting    = false; break;
    default:                                  break;
    }
}

- (void)draw
{
    [self setNeedsDisplay:YES];
}

- (void)doOneTimeSetup
{
    NSTextView *view = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, BOX_SIZE, BOX_SIZE)];
    [view setBackgroundColor:[NSColor clearColor]];
    [view setTypingAttributes:
        [NSDictionary dictionaryWithObject:[NSColor whiteColor]
                                    forKey:NSForegroundColorAttributeName]];
    [view setFont:[NSFont fontWithName:@"Helvetica Bold" size:26.0f]];
    [view setAlignment:NSCenterTextAlignment];
    
    for (unsigned i = 0; i < 26; ++i)
    {
        [view setString:[NSString stringWithCharacters:(unichar[]){ 'A' + i } length:1]];
    
        glGenTextures(1, textures + i);
        glBindTexture(GL_TEXTURE_2D, textures[i]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        TexImageNSView(GL_TEXTURE_2D, view);
    }
    
    wordView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 800, BOX_SIZE)];
    [wordView setBackgroundColor:[NSColor clearColor]];
    [wordView setTypingAttributes:
        [NSDictionary dictionaryWithObject:[NSColor whiteColor]
                                    forKey:NSForegroundColorAttributeName]];
    [wordView setFont:[NSFont fontWithName:@"Helvetica Bold" size:26.0f]];
    glGenTextures(1, &wordTexture);
    glBindTexture(GL_TEXTURE_2D, wordTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    TexImageNSView(GL_TEXTURE_2D, wordView);
}

- (void)update:(NSTimeInterval)dt
{
    if (movingLeft)  playerPosition.x -= dt * X_SPEED;
    if (movingRight) playerPosition.x += dt * X_SPEED;
    if (playerPosition.x < MIN_X) playerPosition.x = MIN_X;
    if (playerPosition.x > MAX_X) playerPosition.x = MAX_X;
    
    for (unsigned i = 0; i < shotCount; ++i)
    {
        shots[i].y += dt * SHOT_SPEED;
        if (shots[i].y > 500.0 + 0.5 * BOX_SIZE)
        {
            memmove(shots + i, shots + i + 1, (shotCount - i) * sizeof(shots[0]));
            --i;
            --shotCount;
        }
    }
    timeSinceShot += dt;
    if (shooting && shotCount + 1 < MAX_SHOTS && timeSinceShot >= SHOT_INTERVAL)
    {
        shots[shotCount++] = playerPosition;
        timeSinceShot = 0.0;
    }
    
    enemyInterval -= dt * ENEMY_INTERVAL_DECREASE;
    for (unsigned i = 0; i < enemyCount; ++i)
    {
        enemies[i].position.y -= dt * ENEMY_SPEED;
        
        NSRect enemyRect = NSMakeRect(enemies[i].position.x - 0.5 * BOX_SIZE, enemies[i].position.y - 0.5 * BOX_SIZE, BOX_SIZE, BOX_SIZE);
        NSRect playerRect = NSMakeRect(playerPosition.x - 0.5 * BOX_SIZE, playerPosition.y - 0.5 * BOX_SIZE, BOX_SIZE, BOX_SIZE);
        
        if (enemies[i].position.y < -0.5 * BOX_SIZE)
        {
            memmove(enemies + i, enemies + i + 1, (enemyCount - i) * sizeof(enemies[0]));
            --i;
            --enemyCount;
        }
        else if (NSIntersectsRect(enemyRect, playerRect))
        {
            [NSApp terminate:self];
        }
        else
        {
            for (unsigned j = 0; j < shotCount; ++j)
            {
                NSRect shotRect = NSMakeRect(shots[j].x - 0.15 * BOX_SIZE, shots[j].y - 0.45 * BOX_SIZE, 0.3 * BOX_SIZE, 0.9 * BOX_SIZE);
                if (NSIntersectsRect(enemyRect, shotRect))
                {
                    [word appendFormat:@"%c", enemies[i].letter];
                    
                    memmove(enemies + i, enemies + i + 1, (enemyCount - i) * sizeof(enemies[0]));
                    --i;
                    --enemyCount;
                    
                    memmove(shots + j, shots + j + 1, (shotCount - j) * sizeof(shots[0]));
                    --j;
                    --shotCount;
                    
                    break;
                }
            }
        }
    }
    timeSinceEnemy += dt;
    if (enemyCount + 1 < MAX_ENEMIES && timeSinceEnemy >= enemyInterval)
    {
        enemies[enemyCount].position.x = arc4random_uniform(800);
        enemies[enemyCount].position.y = 500.0 + 0.5 * BOX_SIZE;
        enemies[enemyCount].letter = [Letters characterAtIndex:arc4random_uniform((uint32_t)[Letters length])];
        ++enemyCount;
        timeSinceEnemy = 0.0;
    }
    
    if ([word length] > 3)
    {
        bool correct = ![[NSSpellChecker sharedSpellChecker] checkSpellingOfString:[word lowercaseString] startingAt:0].length;
        if (correct)
        {
            unsigned n = MIN(enemyCount, 5);
            memmove(enemies, enemies + n, (enemyCount - n) * sizeof(enemies[0]));
            enemyCount -= n;
        }
        if (bomb || correct) word = [NSMutableString string];
    }
    bomb = false;
}

- (void)drawRect:(NSRect)dirtyRect
{
    if (firstFrame)
    {
        [self doOneTimeSetup];
        firstFrame = false;
    }

    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    while (now - lastFrameTime >= SIM_RATE)
    {
        [self update:SIM_RATE];
        lastFrameTime += SIM_RATE;
    }
    
    [wordView setString:word];
    glBindTexture(GL_TEXTURE_2D, wordTexture);
    TexSubImageNSView(GL_TEXTURE_2D, wordView, 0, 0);
    
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    gluOrtho2D(0, 800, 0, 500);
    glMatrixMode(GL_MODELVIEW);
    
    glEnable(GL_TEXTURE_2D);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_BLEND);
    
    for (unsigned i = 0; i < enemyCount; ++i)
    {
        glBindTexture(GL_TEXTURE_2D, textures[enemies[i].letter - 'A']);
        glBegin(GL_QUADS);
        glTexCoord2f(0.0, 1.0);
        glVertex2f(enemies[i].position.x - 0.5 * BOX_SIZE, enemies[i].position.y - 0.5 * BOX_SIZE);
        glTexCoord2f(1.0, 1.0);
        glVertex2f(enemies[i].position.x + 0.5 * BOX_SIZE, enemies[i].position.y - 0.5 * BOX_SIZE);
        glTexCoord2f(1.0, 0.0);
        glVertex2f(enemies[i].position.x + 0.5 * BOX_SIZE, enemies[i].position.y + 0.5 * BOX_SIZE);
        glTexCoord2f(0.0, 0.0);
        glVertex2f(enemies[i].position.x - 0.5 * BOX_SIZE, enemies[i].position.y + 0.5 * BOX_SIZE);
        glEnd();
    }
    
    glColor3f(0.6, 0.6, 0.6);
    glBindTexture(GL_TEXTURE_2D, wordTexture);
    glBegin(GL_QUADS);
    glTexCoord2f(0.0, 1.0);
    glVertex2f(0.0, 0.0);
    glTexCoord2f(1.0, 1.0);
    glVertex2f(800.0, 0.0);
    glTexCoord2f(1.0, 0.0);
    glVertex2f(800.0, BOX_SIZE);
    glTexCoord2f(0.0, 0.0);
    glVertex2f(0.0, BOX_SIZE);
    glEnd();
    glColor3f(1.0, 1.0, 1.0);
    
    glDisable(GL_BLEND);
    glDisable(GL_TEXTURE_2D);
    
    for (unsigned i = 0; i < shotCount; ++i)
    {
        glBegin(GL_QUADS);
        glVertex2f(shots[i].x - 0.15 * BOX_SIZE, shots[i].y - 0.45 * BOX_SIZE);
        glVertex2f(shots[i].x + 0.15 * BOX_SIZE, shots[i].y - 0.45 * BOX_SIZE);
        glVertex2f(shots[i].x + 0.15 * BOX_SIZE, shots[i].y + 0.45 * BOX_SIZE);
        glVertex2f(shots[i].x - 0.15 * BOX_SIZE, shots[i].y + 0.45 * BOX_SIZE);
        glEnd();
    }

    glBegin(GL_QUADS);
    glVertex2f(playerPosition.x - 0.5 * BOX_SIZE, playerPosition.y - 0.5 * BOX_SIZE);
    glVertex2f(playerPosition.x + 0.5 * BOX_SIZE, playerPosition.y - 0.5 * BOX_SIZE);
    glVertex2f(playerPosition.x + 0.5 * BOX_SIZE, playerPosition.y + 0.5 * BOX_SIZE);
    glVertex2f(playerPosition.x - 0.5 * BOX_SIZE, playerPosition.y + 0.5 * BOX_SIZE);
    glEnd();
    
    [[self openGLContext] flushBuffer];
}

@end
