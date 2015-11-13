//
//  PureiGameCore.m
//  Play!
//
//  Created by Alexander Strange on 10/24/15.
//
//

#import "PureiGameCore.h"
#import "PS2VM.h"
#import "gs/GSH_OpenGL/GSH_OpenGL.h"
#import "PadHandler.h"
#import "SoundHandler.h"
#import "PS2VM_Preferences.h"
#import "AppConfig.h"
#import "StdStream.h"

#import <OpenEmuBase/OERingBuffer.h>
#import <OpenEmuBase/OETimingUtils.h>

static __weak PureiGameCore *_current;

class CGSH_OpenEmu : public CGSH_OpenGL
{
public:
    static FactoryFunction	GetFactoryFunction();
    virtual void			InitializeImpl();
protected:
    virtual void			PresentBackbuffer();
};

class CSH_OpenEmu : public CSoundHandler
{
public:
    CSH_OpenEmu() {};
    virtual ~CSH_OpenEmu() {};
    virtual void		Reset();
    virtual void		Write(int16*, unsigned int, unsigned int);
    virtual bool		HasFreeBuffers();
    virtual void		RecycleBuffers();

    static FactoryFunction	GetFactoryFunction();
};

@implementation PureiGameCore
{
    @public
    // ivars
    CPS2VM _ps2VM;
    NSString *_romPath;
}

- (void)dealloc
{
    _current = nil;
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError **)error
{
    _romPath = path;
    return YES;
}

- (void)setupEmulation
{
    _current = self;

    _ps2VM.Initialize();

    CAppConfig::GetInstance().SetPreferenceString(PS2VM_CDROM0PATH, [_romPath fileSystemRepresentation]);
    CAppConfig::GetInstance().SetPreferenceInteger(PREF_CGSHANDLER_PRESENTATION_MODE, CGSHandler::PRESENTATION_MODE_FIT);

    // TODO: In Debug disable dynarec?
    // TODO: TODO: Set mc0, mc1 directories to save dir. Set host directory to BIOS dir?
}

// TODO: pause/play

// TODO: save states

- (void)startEmulation
{
    _ps2VM.CreateGSHandler(CGSH_OpenEmu::GetFactoryFunction());
//    _ps2VM.CreatePadHandler(NULL);
    _ps2VM.CreateSoundHandler(CSH_OpenEmu::GetFactoryFunction());

    CGSHandler::PRESENTATION_PARAMS presentationParams;
    auto presentationMode = static_cast<CGSHandler::PRESENTATION_MODE>(CAppConfig::GetInstance().GetPreferenceInteger(PREF_CGSHANDLER_PRESENTATION_MODE));
    presentationParams.windowWidth = 640;
    presentationParams.windowHeight = 480;
    presentationParams.mode = presentationMode;
    _ps2VM.m_ee->m_gs->SetPresentationParams(presentationParams);

    CPS2OS* os = _ps2VM.m_ee->m_os;
    os->BootFromCDROM(CPS2OS::ArgumentList());

    // TODO: Play! starts a bunch of threads. They all need to be realtime.
    _ps2VM.Resume();

    [super startEmulation];
}

- (void)executeFrame
{
    // Do nothing.
}

- (OEGameCoreRendering)gameCoreRendering
{
    return OEGameCoreRenderingOpenGL2Video;
}

- (NSTimeInterval)frameInterval
{
    return 60;
}

- (OEIntSize)bufferSize
{
    return OEIntSizeMake(640, 480);
}

- (OEIntSize)aspectSize
{
    return OEIntSizeMake(4,3);
}

- (BOOL)hasAlternateRenderingThread
{
    return YES;
}

- (NSUInteger)channelCount
{
    return 2;
}

- (double)audioSampleRate
{
    return 44100; // TODO: is this right?
}

- (NSUInteger)audioBufferSizeForBuffer:(NSUInteger)buffer
{
    return 2*[super audioBufferSizeForBuffer:buffer];
}

@end

#pragma mark - Graphics callbacks

static CGSHandler *GSHandlerFactory()
{
    return new CGSH_OpenEmu();
}

CGSHandler::FactoryFunction CGSH_OpenEmu::GetFactoryFunction()
{
    return GSHandlerFactory;
}

void CGSH_OpenEmu::InitializeImpl()
{
    GET_CURRENT_OR_RETURN();

    [current.renderDelegate willRenderFrameOnAlternateThread];
    CGSH_OpenGL::InitializeImpl();

    this->m_presentFramebuffer = [current.renderDelegate.presentationFramebuffer intValue];

    glClearColor(0,0,0,0);
    glClear(GL_COLOR_BUFFER_BIT);
}

void CGSH_OpenEmu::PresentBackbuffer()
{
    GET_CURRENT_OR_RETURN();

    [current.renderDelegate didRenderFrameOnAlternateThread];

    // Start the next one.
    [current.renderDelegate willRenderFrameOnAlternateThread];
}

// TODO: Implement pad handler/input

void CSH_OpenEmu::Reset()
{

}

bool CSH_OpenEmu::HasFreeBuffers()
{
    return true;
}

void CSH_OpenEmu::RecycleBuffers()
{

}

void CSH_OpenEmu::Write(int16 *audio, unsigned int sampleCount, unsigned int sampleRate)
{
    GET_CURRENT_OR_RETURN();

    OERingBuffer *rb = [current ringBufferAtIndex:0];
    [rb write:audio maxLength:sampleCount*2];
}

static CSoundHandler *SoundHandlerFactory()
{
    OESetThreadRealtime(1. / (1 * 60), .007, .03);
    return new CSH_OpenEmu();
}

CSoundHandler::FactoryFunction CSH_OpenEmu::GetFactoryFunction()
{
    return SoundHandlerFactory;
}