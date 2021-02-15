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

__weak PureiGameCore *_current;

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

class CPH_OpenEmu : public CPadHandler
{
public:
	CPH_OpenEmu() {};
    virtual                 ~CPH_OpenEmu() {};
    void                    Update(uint8*);
    
    static FactoryFunction	GetFactoryFunction();
};

class CBinding
{
public:
    virtual			~CBinding() {}
    
    virtual void	ProcessEvent(OEPS2Button, uint32) = 0;
    
    virtual uint32	GetValue() const = 0;
};

typedef std::shared_ptr<CBinding> BindingPtr;

class CSimpleBinding : public CBinding
{
public:
    CSimpleBinding(OEPS2Button);
    virtual         ~CSimpleBinding();
    
    virtual void    ProcessEvent(OEPS2Button, uint32);
    
    virtual uint32  GetValue() const;
    
private:
    OEPS2Button     m_keyCode;
    uint32          m_state;
};

class CSimulatedAxisBinding : public CBinding
{
public:
    CSimulatedAxisBinding(OEPS2Button, OEPS2Button);
    virtual         ~CSimulatedAxisBinding();
    
    virtual void    ProcessEvent(OEPS2Button, uint32);
    
    virtual uint32  GetValue() const;
    
private:
    OEPS2Button     m_negativeKeyCode;
    OEPS2Button     m_positiveKeyCode;
    
    uint32          m_negativeState;
    uint32          m_positiveState;
};


@interface PureiGameCore() <OEPS2SystemResponderClient>

@end

@implementation PureiGameCore
{
    @public
    // ivars
    CPS2VM _ps2VM;
    NSString *_romPath;
    BindingPtr _bindings[PS2::CControllerInfo::MAX_BUTTONS];
}

- (void)dealloc
{
    _current = nil;
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError **)error
{
    _romPath = [path copy];
    return YES;
}

- (void)setupEmulation
{
    _current = self;

    CAppConfig::GetInstance().SetPreferencePath(PREF_PS2_CDROM0_PATH, [_romPath fileSystemRepresentation]);
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *mcd0 = [self.batterySavesDirectoryPath stringByAppendingPathComponent:@"mcd0"];
    NSString *mcd1 = [self.batterySavesDirectoryPath stringByAppendingPathComponent:@"mcd1"];
    NSString *hdd = [self.batterySavesDirectoryPath stringByAppendingPathComponent:@"hdd"];

    if (![fm fileExistsAtPath:mcd0]) {
        [fm createDirectoryAtPath:mcd0 withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    if (![fm fileExistsAtPath:mcd1]) {
        [fm createDirectoryAtPath:mcd1 withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    if (![fm fileExistsAtPath:hdd]) {
        [fm createDirectoryAtPath:hdd withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    CAppConfig::GetInstance().SetPreferencePath(PREF_PS2_MC0_DIRECTORY, mcd0.fileSystemRepresentation);
    CAppConfig::GetInstance().SetPreferencePath(PREF_PS2_MC1_DIRECTORY, mcd1.fileSystemRepresentation);
    CAppConfig::GetInstance().SetPreferencePath(PREF_PS2_HOST_DIRECTORY, hdd.fileSystemRepresentation);
    CAppConfig::GetInstance().SetPreferencePath(PREF_PS2_ROM0_DIRECTORY, self.biosDirectoryPath.fileSystemRepresentation);
    CAppConfig::GetInstance().SetPreferenceInteger(PREF_CGSHANDLER_PRESENTATION_MODE, CGSHandler::PRESENTATION_MODE_FIT);
    CAppConfig::GetInstance().Save();
    
    _ps2VM.Initialize();

    _bindings[PS2::CControllerInfo::START] = std::make_shared<CSimpleBinding>(OEPS2ButtonStart);
    _bindings[PS2::CControllerInfo::SELECT] = std::make_shared<CSimpleBinding>(OEPS2ButtonSelect);
    _bindings[PS2::CControllerInfo::DPAD_LEFT] = std::make_shared<CSimpleBinding>(OEPS2ButtonLeft);
    _bindings[PS2::CControllerInfo::DPAD_RIGHT] = std::make_shared<CSimpleBinding>(OEPS2ButtonRight);
    _bindings[PS2::CControllerInfo::DPAD_UP] = std::make_shared<CSimpleBinding>(OEPS2ButtonUp);
    _bindings[PS2::CControllerInfo::DPAD_DOWN] = std::make_shared<CSimpleBinding>(OEPS2ButtonDown);
    _bindings[PS2::CControllerInfo::SQUARE] = std::make_shared<CSimpleBinding>(OEPS2ButtonSquare);
    _bindings[PS2::CControllerInfo::CROSS] = std::make_shared<CSimpleBinding>(OEPS2ButtonCross);
    _bindings[PS2::CControllerInfo::TRIANGLE] = std::make_shared<CSimpleBinding>(OEPS2ButtonTriangle);
    _bindings[PS2::CControllerInfo::CIRCLE] = std::make_shared<CSimpleBinding>(OEPS2ButtonCircle);
    _bindings[PS2::CControllerInfo::L1] = std::make_shared<CSimpleBinding>(OEPS2ButtonL1);
    _bindings[PS2::CControllerInfo::L2] = std::make_shared<CSimpleBinding>(OEPS2ButtonL2);
    _bindings[PS2::CControllerInfo::L3] = std::make_shared<CSimpleBinding>(OEPS2ButtonL3);
    _bindings[PS2::CControllerInfo::R1] = std::make_shared<CSimpleBinding>(OEPS2ButtonR1);
    _bindings[PS2::CControllerInfo::R2] = std::make_shared<CSimpleBinding>(OEPS2ButtonR2);
    _bindings[PS2::CControllerInfo::R3] = std::make_shared<CSimpleBinding>(OEPS2ButtonR3);
    _bindings[PS2::CControllerInfo::R3] = std::make_shared<CSimpleBinding>(OEPS2ButtonR3);
    _bindings[PS2::CControllerInfo::ANALOG_LEFT_X] = std::make_shared<CSimulatedAxisBinding>(OEPS2LeftAnalogLeft,OEPS2LeftAnalogRight);
    _bindings[PS2::CControllerInfo::ANALOG_LEFT_Y] = std::make_shared<CSimulatedAxisBinding>(OEPS2LeftAnalogUp,OEPS2LeftAnalogDown);
    _bindings[PS2::CControllerInfo::ANALOG_RIGHT_X] = std::make_shared<CSimulatedAxisBinding>(OEPS2RightAnalogLeft,OEPS2RightAnalogRight);
    _bindings[PS2::CControllerInfo::ANALOG_RIGHT_Y] = std::make_shared<CSimulatedAxisBinding>(OEPS2RightAnalogUp,OEPS2RightAnalogDown);

    // TODO: In Debug disable dynarec?
}

- (void)setPauseEmulation:(BOOL)pauseEmulation
{
    if (pauseEmulation) {
        _ps2VM.Pause();
    } else {
        _ps2VM.Resume();
    }
    
    [super setPauseEmulation:pauseEmulation];
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
    const fs::path fsName(fileName.fileSystemRepresentation);
    auto success = _ps2VM.SaveState(fsName);
    success.wait();
    block(success.get(), nil);
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
    //FIXME: load save state at launch fails.
    const fs::path fsName(fileName.fileSystemRepresentation);
    auto success = _ps2VM.LoadState(fsName);
    success.wait();
    block(success.get(), nil);
}

- (void)startEmulation
{
    _ps2VM.CreateGSHandler(CGSH_OpenEmu::GetFactoryFunction());
    _ps2VM.CreatePadHandler(CPH_OpenEmu::GetFactoryFunction());
    _ps2VM.CreateSoundHandler(CSH_OpenEmu::GetFactoryFunction());

    CGSHandler::PRESENTATION_PARAMS presentationParams;
    auto presentationMode = static_cast<CGSHandler::PRESENTATION_MODE>(CAppConfig::GetInstance().GetPreferenceInteger(PREF_CGSHANDLER_PRESENTATION_MODE));
    presentationParams.windowWidth = 640;
    presentationParams.windowHeight = 480;
    presentationParams.mode = presentationMode;
    _ps2VM.m_ee->m_gs->SetPresentationParams(presentationParams);

    CPS2OS* os = _ps2VM.m_ee->m_os;
    os->BootFromCDROM();

    // TODO: Play! starts a bunch of threads. They all need to be realtime.
    _ps2VM.Resume();

    [super startEmulation];
}

- (void)resetEmulation
{
    _ps2VM.Pause();
    _ps2VM.Reset();
    _ps2VM.Resume();
}

-(void)stopEmulation
{
    _ps2VM.Pause();
    _ps2VM.Destroy();
}

- (void)executeFrame
{
    // Do nothing.
}

- (OEGameCoreRendering)gameCoreRendering
{
    return OEGameCoreRenderingOpenGL3Video;
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

- (oneway void)didMovePS2JoystickDirection:(OEPS2Button)button withValue:(CGFloat)value forPlayer:(NSUInteger)player
{
    //TODO: find real scale value
    uint32 val = value * 0x7f;
    for(auto bindingIterator(std::begin(_bindings));
        bindingIterator != std::end(_bindings); bindingIterator++)
    {
        const auto& binding = (*bindingIterator);
        if(!binding) continue;
        binding->ProcessEvent(button, val);
    }
}

- (oneway void)didPushPS2Button:(OEPS2Button)button forPlayer:(NSUInteger)player
{
    for(auto bindingIterator(std::begin(_bindings));
        bindingIterator != std::end(_bindings); bindingIterator++)
    {
        const auto& binding = (*bindingIterator);
        if(!binding) continue;
        binding->ProcessEvent(button, 1);
    }
}

- (oneway void)didReleasePS2Button:(OEPS2Button)button forPlayer:(NSUInteger)player
{
    for(auto bindingIterator(std::begin(_bindings));
        bindingIterator != std::end(_bindings); bindingIterator++)
    {
        const auto& binding = (*bindingIterator);
        if(!binding) continue;
        binding->ProcessEvent(button, 0);
    }
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

    OERingBuffer *rb = [current audioBufferAtIndex:0];
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

void CPH_OpenEmu::Update(uint8* ram)
{
	GET_CURRENT_OR_RETURN();
    
    for(auto listenerIterator(std::begin(m_listeners));
        listenerIterator != std::end(m_listeners); listenerIterator++)
    {
        auto* listener(*listenerIterator);
        
        for(unsigned int i = 0; i < PS2::CControllerInfo::MAX_BUTTONS; i++)
        {
            const auto& binding = current->_bindings[i];
            if(!binding) continue;
            uint32 value = binding->GetValue();
            auto currentButtonId = static_cast<PS2::CControllerInfo::BUTTON>(i);
            if(PS2::CControllerInfo::IsAxis(currentButtonId))
            {
                listener->SetAxisState(0, currentButtonId, value & 0xFF, ram);
            }
            else
            {
                listener->SetButtonState(0, currentButtonId, value != 0, ram);
            }
        }
    }

}

static CPadHandler *PadHandlerFactory()
{
    return new CPH_OpenEmu();
}

CPadHandler::FactoryFunction CPH_OpenEmu::GetFactoryFunction()
{
    return PadHandlerFactory;
}

//---------------------------------------------------------------------------------

CSimpleBinding::CSimpleBinding(OEPS2Button keyCode)
: m_keyCode(keyCode)
, m_state(0)
{
	
}

CSimpleBinding::~CSimpleBinding() = default;

void CSimpleBinding::ProcessEvent(OEPS2Button keyCode, uint32 state)
{
    if(keyCode != m_keyCode) return;
    m_state = state;
}

uint32 CSimpleBinding::GetValue() const
{
    return m_state;
}

//---------------------------------------------------------------------------------
CSimulatedAxisBinding::CSimulatedAxisBinding(OEPS2Button negativeKeyCode, OEPS2Button positiveKeyCode)
: m_negativeKeyCode(negativeKeyCode)
, m_positiveKeyCode(positiveKeyCode)
, m_negativeState(0)
, m_positiveState(0)
{
    
}

CSimulatedAxisBinding::~CSimulatedAxisBinding() = default;

void CSimulatedAxisBinding::ProcessEvent(OEPS2Button keyCode, uint32 state)
{
    if(keyCode == m_negativeKeyCode)
    {
        m_negativeState = state;
    }
    
    if(keyCode == m_positiveKeyCode)
    {
        m_positiveState = state;
    }
}

uint32 CSimulatedAxisBinding::GetValue() const
{
    uint32 value = 0x7F;
    
    if(m_negativeState)
    {
        value -= m_negativeState;
    } else
    if(m_positiveState)
    {
        value += m_positiveState;
    }
    
    return value;
}
