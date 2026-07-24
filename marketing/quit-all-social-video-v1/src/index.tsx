import React from 'react';
import {
  AbsoluteFill,
  Audio,
  Composition,
  Easing,
  Img,
  Sequence,
  interpolate,
  registerRoot,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';

const GOLD = '#d8ad3d';
const GOLD_LIGHT = '#ffe48b';
const RED = '#e5322d';
const OFF_WHITE = '#f8f5ec';
const MUTED = '#b7b3aa';

const clamp = {
  extrapolateLeft: 'clamp' as const,
  extrapolateRight: 'clamp' as const,
};

const screenshots = [
  '01-streak.png',
  '02-habits.png',
  '03-sos.png',
  '04-stats.png',
  '05-restart.png',
];

const Background: React.FC<{accent?: 'gold' | 'red'}> = ({accent = 'gold'}) => {
  const frame = useCurrentFrame();
  const drift = interpolate(frame, [0, 540], [-80, 100]);
  const color = accent === 'red' ? 'rgba(229,50,45,0.24)' : 'rgba(216,173,61,0.22)';

  return (
    <AbsoluteFill
      style={{
        overflow: 'hidden',
        background:
          'radial-gradient(circle at 50% 18%, #202020 0%, #0d0d0d 38%, #030303 78%)',
      }}
    >
      <div
        style={{
          position: 'absolute',
          width: 820,
          height: 820,
          left: -430 + drift,
          top: 230,
          borderRadius: '50%',
          background: `radial-gradient(circle, ${color}, rgba(0,0,0,0) 68%)`,
          filter: 'blur(26px)',
        }}
      />
      <div
        style={{
          position: 'absolute',
          width: 720,
          height: 720,
          right: -400 - drift * 0.5,
          bottom: 40,
          borderRadius: '50%',
          background:
            'radial-gradient(circle, rgba(229,50,45,0.13), rgba(0,0,0,0) 70%)',
          filter: 'blur(34px)',
        }}
      />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          opacity: 0.08,
          backgroundImage:
            'linear-gradient(rgba(255,255,255,.14) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,.14) 1px, transparent 1px)',
          backgroundSize: '72px 72px',
          maskImage: 'linear-gradient(to bottom, black, transparent 80%)',
        }}
      />
    </AbsoluteFill>
  );
};

const SceneFade: React.FC<{
  duration: number;
  children: React.ReactNode;
  fadeIn?: number;
  fadeOut?: number;
}> = ({duration, children, fadeIn = 10, fadeOut = 12}) => {
  const frame = useCurrentFrame();
  const opacity =
    fadeOut === 0
      ? interpolate(frame, [0, fadeIn, duration], [0, 1, 1], clamp)
      : interpolate(
          frame,
          [0, fadeIn, duration - fadeOut, duration],
          [0, 1, 1, 0],
          clamp,
        );
  return <AbsoluteFill style={{opacity}}>{children}</AbsoluteFill>;
};

const Kicker: React.FC<{children: React.ReactNode; color?: string}> = ({
  children,
  color = GOLD_LIGHT,
}) => (
  <div
    style={{
      fontFamily: 'Arial, Helvetica, sans-serif',
      fontSize: 28,
      fontWeight: 800,
      letterSpacing: 8,
      color,
      textTransform: 'uppercase',
    }}
  >
    {children}
  </div>
);

const HeroText: React.FC<{
  children: React.ReactNode;
  size?: number;
  align?: 'left' | 'center';
}> = ({children, size = 110, align = 'left'}) => (
  <div
    style={{
      fontFamily: 'Arial, Helvetica, sans-serif',
      fontSize: size,
      lineHeight: 0.93,
      fontWeight: 900,
      letterSpacing: -5,
      color: OFF_WHITE,
      textAlign: align,
      textWrap: 'balance',
    }}
  >
    {children}
  </div>
);

const ProblemScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const titleScale = spring({fps, frame, config: {damping: 13, stiffness: 130}});
  const habits = ['SMOKING', 'VAPING', 'ALCOHOL', 'SOCIAL MEDIA', 'GAMBLING', 'CAFFEINE'];

  return (
    <SceneFade duration={96} fadeOut={16}>
      <Background accent="red" />
      <AbsoluteFill style={{padding: '240px 86px 210px', justifyContent: 'space-between'}}>
        <div style={{transform: `scale(${0.84 + titleScale * 0.16})`, transformOrigin: 'left center'}}>
          <Kicker color="#ff7b72">THE HABIT LOOP</Kicker>
          <div style={{height: 28}} />
          <HeroText size={142}>
            TRYING
            <br />
            TO QUIT?
          </HeroText>
        </div>
        <div style={{display: 'flex', flexWrap: 'wrap', gap: 18}}>
          {habits.map((habit, index) => {
            const value = spring({
              fps,
              frame: frame - 18 - index * 5,
              config: {damping: 14, stiffness: 150},
            });
            return (
              <div
                key={habit}
                style={{
                  opacity: value,
                  transform: `translateY(${(1 - value) * 42}px)`,
                  border: `2px solid ${index === 0 ? RED : 'rgba(255,255,255,.22)'}`,
                  background: index === 0 ? 'rgba(229,50,45,.18)' : 'rgba(255,255,255,.05)',
                  color: index === 0 ? '#ffb0aa' : '#ddd9cf',
                  borderRadius: 999,
                  padding: '19px 27px',
                  fontFamily: 'Arial, Helvetica, sans-serif',
                  fontSize: 28,
                  fontWeight: 800,
                  letterSpacing: 2.5,
                }}
              >
                {habit}
              </div>
            );
          })}
        </div>
      </AbsoluteFill>
    </SceneFade>
  );
};

const ScreenshotCard: React.FC<{
  file: string;
  width: number;
  rotate?: number;
  shadowColor?: string;
}> = ({file, width, rotate = 0, shadowColor = 'rgba(216,173,61,.24)'}) => (
  <div
    style={{
      width,
      borderRadius: 44,
      overflow: 'hidden',
      transform: `rotate(${rotate}deg)`,
      boxShadow: `0 42px 100px ${shadowColor}, 0 0 0 2px rgba(255,255,255,.13)`,
      background: '#fff',
    }}
  >
    <Img src={staticFile(file)} style={{display: 'block', width: '100%', height: 'auto'}} />
  </div>
);

const HabitsScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const enter = spring({fps, frame, config: {damping: 16, stiffness: 105}});
  const y = interpolate(enter, [0, 1], [210, 0]);
  const rotate = interpolate(enter, [0, 1], [-8, -2]);

  return (
    <SceneFade duration={112}>
      <Background />
      <AbsoluteFill style={{padding: '220px 76px 120px'}}>
        <Kicker>QUIT ALL</Kicker>
        <div style={{height: 24}} />
        <HeroText size={104}>
          ONE APP.
          <br />
          EVERY HABIT.
        </HeroText>
        <div
          style={{
            position: 'absolute',
            width: 610,
            right: 54,
            top: 475,
            transform: `translateY(${y}px) rotate(${rotate}deg)`,
          }}
        >
          <ScreenshotCard file="02-habits.png" width={610} shadowColor="rgba(216,173,61,.32)" />
        </div>
        <div
          style={{
            position: 'absolute',
            left: 82,
            bottom: 310,
            width: 360,
            color: MUTED,
            fontFamily: 'Arial, Helvetica, sans-serif',
            fontSize: 34,
            lineHeight: 1.25,
            fontWeight: 700,
          }}
        >
          Pick the battles that matter to you.
        </div>
      </AbsoluteFill>
    </SceneFade>
  );
};

const SosScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const enter = spring({fps, frame, config: {damping: 16, stiffness: 115}});
  const pulse = 1 + Math.sin(frame / 6) * 0.016;

  return (
    <SceneFade duration={126}>
      <Background accent="red" />
      <AbsoluteFill style={{padding: '220px 70px 120px'}}>
        <Kicker color="#ff8f87">THE HARD MOMENT</Kicker>
        <div style={{height: 22}} />
        <HeroText size={95}>
          WHEN THE
          <br />
          URGE HITS.
        </HeroText>
        <div
          style={{
            position: 'absolute',
            width: 650,
            left: 215,
            top: 475,
            transform: `translateY(${(1 - enter) * 170}px) scale(${pulse})`,
          }}
        >
          <ScreenshotCard file="03-sos.png" width={650} shadowColor="rgba(229,50,45,.28)" />
        </div>
        <div
          style={{
            position: 'absolute',
            right: 70,
            bottom: 320,
            padding: '22px 30px',
            borderRadius: 18,
            background: RED,
            color: '#fff',
            fontFamily: 'Arial, Helvetica, sans-serif',
            fontSize: 34,
            fontWeight: 900,
            letterSpacing: 1,
            transform: `translateX(${(1 - enter) * 120}px)`,
          }}
        >
          HIT SOS.
        </div>
      </AbsoluteFill>
    </SceneFade>
  );
};

const ProofScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const left = spring({fps, frame, config: {damping: 15, stiffness: 110}});
  const right = spring({fps, frame: frame - 8, config: {damping: 15, stiffness: 110}});

  return (
    <SceneFade duration={112}>
      <Background />
      <AbsoluteFill style={{padding: '215px 64px 130px'}}>
        <Kicker>VISIBLE PROGRESS</Kicker>
        <div style={{height: 22}} />
        <HeroText size={88}>
          SEE THE STREAK.
          <br />
          SEE THE SAVINGS.
        </HeroText>
        <div
          style={{
            position: 'absolute',
            left: 45,
            top: 510,
            transform: `translateX(${(1 - left) * -240}px) rotate(-5deg)`,
          }}
        >
          <ScreenshotCard file="01-streak.png" width={535} rotate={-2} />
        </div>
        <div
          style={{
            position: 'absolute',
            right: 20,
            top: 650,
            transform: `translateX(${(1 - right) * 240}px) rotate(6deg)`,
          }}
        >
          <ScreenshotCard file="04-stats.png" width={535} rotate={2} />
        </div>
      </AbsoluteFill>
    </SceneFade>
  );
};

const GalleryScene: React.FC = () => {
  const frame = useCurrentFrame();
  const x = interpolate(frame, [0, 105], [70, -1220], {
    ...clamp,
    easing: Easing.inOut(Easing.cubic),
  });

  return (
    <SceneFade duration={116}>
      <Background />
      <AbsoluteFill style={{paddingTop: 215}}>
        <div style={{padding: '0 72px'}}>
          <Kicker>KEEP GOING</Kicker>
          <div style={{height: 20}} />
          <HeroText size={86}>
            NO SHAME.
            <br />
            RESTART.
          </HeroText>
        </div>
        <div
          style={{
            position: 'absolute',
            top: 510,
            left: 0,
            display: 'flex',
            gap: 30,
            transform: `translateX(${x}px)`,
          }}
        >
          {[...screenshots, ...screenshots.slice(0, 2)].map((file, index) => (
            <ScreenshotCard
              key={`${file}-${index}`}
              file={file}
              width={410}
              rotate={index % 2 === 0 ? -2 : 2}
              shadowColor="rgba(0,0,0,.42)"
            />
          ))}
        </div>
        <div
          style={{
            position: 'absolute',
            left: 72,
            right: 72,
            bottom: 290,
            height: 5,
            borderRadius: 999,
            background: 'rgba(255,255,255,.12)',
            overflow: 'hidden',
          }}
        >
          <div
            style={{
              height: '100%',
              width: `${interpolate(frame, [0, 105], [8, 100], clamp)}%`,
              background: `linear-gradient(90deg, ${RED}, ${GOLD_LIGHT})`,
            }}
          />
        </div>
      </AbsoluteFill>
    </SceneFade>
  );
};

const CtaScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const enter = spring({fps, frame, config: {damping: 14, stiffness: 120}});
  const glow = 0.35 + Math.sin(frame / 7) * 0.08;

  return (
    <SceneFade duration={75} fadeOut={0}>
      <Background />
      <AbsoluteFill
        style={{
          alignItems: 'center',
          justifyContent: 'center',
          padding: '150px 76px 190px',
          textAlign: 'center',
        }}
      >
        <div
          style={{
            width: 250,
            height: 250,
            borderRadius: 58,
            overflow: 'hidden',
            boxShadow: `0 30px 110px rgba(216,173,61,${glow})`,
            transform: `translateY(${(1 - enter) * 90}px) scale(${0.8 + enter * 0.2})`,
          }}
        >
          <Img src={staticFile('app-icon.png')} style={{width: '100%', height: '100%'}} />
        </div>
        <div style={{height: 52}} />
        <HeroText size={126} align="center">
          QUIT ALL
        </HeroText>
        <div
          style={{
            marginTop: 18,
            color: GOLD_LIGHT,
            fontFamily: 'Arial, Helvetica, sans-serif',
            fontSize: 42,
            fontWeight: 800,
            letterSpacing: 3,
          }}
        >
          BREAK EVERY HABIT
        </div>
        <div
          style={{
            marginTop: 72,
            borderRadius: 22,
            padding: '24px 38px',
            background: OFF_WHITE,
            color: '#111',
            fontFamily: 'Arial, Helvetica, sans-serif',
            fontSize: 34,
            fontWeight: 900,
            boxShadow: '0 22px 70px rgba(0,0,0,.34)',
          }}
        >
          AVAILABLE ON THE APP STORE
        </div>
      </AbsoluteFill>
    </SceneFade>
  );
};

const QuitAllVertical: React.FC = () => {
  return (
    <AbsoluteFill style={{backgroundColor: '#050505'}}>
      <Audio src={staticFile('soundtrack.wav')} volume={0.9} />
      <Sequence from={0} durationInFrames={96}>
        <ProblemScene />
      </Sequence>
      <Sequence from={78} durationInFrames={112}>
        <HabitsScene />
      </Sequence>
      <Sequence from={172} durationInFrames={126}>
        <SosScene />
      </Sequence>
      <Sequence from={280} durationInFrames={112}>
        <ProofScene />
      </Sequence>
      <Sequence from={374} durationInFrames={116}>
        <GalleryScene />
      </Sequence>
      <Sequence from={465} durationInFrames={75}>
        <CtaScene />
      </Sequence>
    </AbsoluteFill>
  );
};

const Root: React.FC = () => (
  <Composition
    id="QuitAllVertical"
    component={QuitAllVertical}
    durationInFrames={540}
    fps={30}
    width={1080}
    height={1920}
  />
);

registerRoot(Root);
