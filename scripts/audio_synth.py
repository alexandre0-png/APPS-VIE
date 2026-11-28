import numpy as np, subprocess, os, wave
SR=44100; rng=np.random.default_rng(3)
def t(d): return np.arange(int(SR*d))/SR
def env(n, a=0.01, r=0.2, curve=2.0):
    e=np.ones(n); na=int(SR*a); nr=int(SR*r)
    if na>0: e[:na]=np.linspace(0,1,na)
    if nr>0: e[-nr:]*=np.linspace(1,0,nr)**curve
    return e
def sine(f,d,amp=1.0): x=t(d); return amp*np.sin(2*np.pi*f*x)
def sweep(f0,f1,d,amp=1.0): x=t(d); f=np.linspace(f0,f1,len(x)); return amp*np.sin(2*np.pi*np.cumsum(f)/SR)
def noise(d,amp=1.0): return amp*(rng.random(int(SR*d))*2-1)
def lowpass(x,k): 
    k=max(1,int(k)); return np.convolve(x,np.ones(k)/k,mode="same")
def highpass(x,k): return x-lowpass(x,k)
def mix(*xs):
    n=max(len(x) for x in xs); y=np.zeros(n)
    for x in xs: y[:len(x)]+=x
    return y
def at(x,delay,total):
    y=np.zeros(int(SR*total)); i=int(SR*delay); y[i:i+len(x)]+=x[:max(0,len(y)-i)]; return y
def save(name,x,peak=0.85):
    x=x/(np.max(np.abs(x))+1e-9)*peak; w=f"audio2/{name}.wav"
    with wave.open(w,"wb") as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(SR); f.writeframes((x*32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg","-y","-loglevel","error","-i",w,"-c:a","libvorbis","-q:a","4",f"audio2/{name}.ogg"]); os.remove(w)
def chime(freqs,d=0.9,gap=0.09):
    return mix(*[at(sine(f,d,0.5)*env(int(SR*d),0.005,d*0.8,3),i*gap,d+gap*len(freqs)) for i,f in enumerate(freqs)])
# --- Grenier ---
d=0.9; save("pas_bois",mix(lowpass(noise(d,1.0),60)*env(int(SR*d),0.002,0.12,3)*0+at(lowpass(noise(0.12,1),30)*env(int(SR*0.12),0.001,0.1,3),0.0,0.9),at(lowpass(noise(0.12,1),30)*env(int(SR*0.12),0.001,0.1,3),0.45,0.9)))
d=6; save("vent_grenier",lowpass(noise(d,1),90)*(0.6+0.4*np.sin(2*np.pi*0.3*t(d)))*env(int(SR*d),1.0,1.0,1))
d=5; save("murmure",mix(lowpass(noise(d,1),25)*(0.5+0.5*np.sin(2*np.pi*3.5*t(d))**2)*0.7, sine(180,d,0.04)*env(int(SR*d),0.8,0.8,1)))
d=1.6; save("sting_monstre",mix(sweep(900,120,d,0.5)*env(int(SR*d),0.01,1.2,2), sweep(70,50,d,0.8)*env(int(SR*d),0.01,1.4,2), noise(d,0.3)*env(int(SR*d),0.005,0.5,3)))
save("cle_ramassee",chime([880,1175,1568],0.7,0.08))
d=0.5; save("porte_verrouillee",mix(sweep(140,60,d,0.9)*env(int(SR*d),0.002,0.35,3), lowpass(noise(d,1),8)*env(int(SR*d),0.001,0.06,2)))
d=0.12; tick=highpass(noise(d,1),6)*env(int(SR*d),0.0005,0.08,4)+sine(1800,d,0.3)*env(int(SR*d),0.0005,0.08,4); save("horloge_tic",mix(at(tick,0,1.0),at(tick*0.7,0.5,1.0)))
d=1.2; save("coffre_ouvre",mix(sweep(90,40,0.3,0.8)*env(int(SR*0.3),0.002,0.25,3), at(chime([660,880],0.8,0.12)*0.6,0.25,d)))
d=3.0; save("chuchotement",highpass(lowpass(noise(d,1),8),40)*(0.3+0.7*(np.sin(2*np.pi*5*t(d))>0.2))*env(int(SR*d),0.3,0.6,1))
d=2.5; save("pas_courses",mix(*[at(lowpass(noise(0.1,1),25)*env(int(SR*0.1),0.001,0.08,3),i*0.25,d) for i in range(9)]))
d=2.0; save("marche_escalier",mix(*[at(lowpass(noise(0.1,1),35)*env(int(SR*0.1),0.001,0.08,3)+sine(110,0.1,0.4)*env(int(SR*0.1),0.001,0.09,3),i*0.32,d) for i in range(6)]))
# --- Chipe-Oeufs ---
d=0.35; save("eclosion_pop",mix(sweep(300,900,d,0.7)*env(int(SR*d),0.002,0.3,3), noise(0.08,0.4)*env(int(SR*0.08),0.001,0.07,2)))
save("eclosion_rare",chime([784,988,1175,1568],0.9,0.1))
save("eclosion_epique",mix(chime([523,659,784,1047,1319],1.1,0.09), sweep(200,800,0.8,0.25)*env(int(SR*0.8),0.01,0.6,2)))
d=2.4; save("eclosion_legendaire",mix(chime([523,659,784,1047,1319,1568,2093],1.4,0.11), sweep(80,400,1.2,0.4)*env(int(SR*1.2),0.01,0.9,2), at(noise(1.0,0.25)*env(int(SR*1.0),0.05,0.9,2),0.2,d)))
d=3.0; save("eclosion_secret",mix(sweep(60,300,1.5,0.7)*env(int(SR*1.5),0.2,0.2,1), at(chime([392,494,587,784,988,1175,1568,2093],1.6,0.13),1.2,d), at(noise(1.2,0.3)*env(int(SR*1.2),0.4,0.6,1),0.3,d)))
save("piece",chime([1318,1760],0.35,0.07))
save("achat",mix(chime([880,1100,1320],0.5,0.06), at(highpass(noise(0.15,1),4)*env(int(SR*0.15),0.001,0.1,3)*0.4,0.05,0.6)))
d=1.4; save("grognement_loup",mix(sweep(120,70,d,0.7)*env(int(SR*d),0.05,0.9,1)*(0.7+0.3*np.sin(2*np.pi*30*t(d))), lowpass(noise(d,1),6)*env(int(SR*d),0.05,0.9,1)*0.5))
d=0.5; save("aboiement",mix(sweep(500,250,d,0.7)*env(int(SR*d),0.005,0.3,3), noise(d,0.2)*env(int(SR*d),0.002,0.15,3)))
d=0.4; save("coup_degat",mix(sweep(220,60,d,0.9)*env(int(SR*d),0.001,0.3,3), noise(0.1,0.6)*env(int(SR*0.1),0.0005,0.09,3)))
d=0.6; save("pics_sortent",mix(sweep(300,1200,d,0.4)*env(int(SR*d),0.001,0.4,3), highpass(noise(d,0.6),8)*env(int(SR*d),0.001,0.3,3)))
d=1.0; save("lame_tourne",mix(highpass(noise(d,1),5)*(0.5+0.5*np.sin(2*np.pi*14*t(d)))*env(int(SR*d),0.1,0.3,1), sweep(400,700,d,0.2)))
d=2.0; save("boulet_roule",mix(lowpass(noise(d,1),50)*(0.6+0.4*np.sin(2*np.pi*6*t(d)))*env(int(SR*d),0.4,0.6,1), sweep(50,45,d,0.8)))
d=4.0; save("fanfare_victoire",mix(*[at(sine(f,0.5,0.5)*env(int(SR*0.5),0.01,0.4,2)+sine(f*2,0.5,0.15)*env(int(SR*0.5),0.01,0.4,2),i*0.18,d) for i,f in enumerate([523,659,784,1047,784,1047,1319])]))
d=0.12; save("clic_menu",sine(1200,d,0.5)*env(int(SR*d),0.001,0.1,3))
d=0.3; save("clic_achat_refuse",sweep(300,150,d,0.5)*env(int(SR*d),0.002,0.25,2))
d=8; save("ambiance_chateau",mix(lowpass(noise(d,1),120)*0.25*(0.7+0.3*np.sin(2*np.pi*0.2*t(d))), sine(55,d,0.3)*env(int(SR*d),2.0,2.0,1), sine(82.4,d,0.18)*env(int(SR*d),2.0,2.0,1)))
d=8; save("ambiance_prairie",mix(lowpass(noise(d,1),150)*0.2*(0.7+0.3*np.sin(2*np.pi*0.15*t(d))), *[at(sweep(2500+i*300,3200+i*200,0.18,0.12)*env(int(SR*0.18),0.01,0.12,2),0.7+i*1.1,d) for i in range(6)]))
print(sorted(f for f in os.listdir("audio2") if f.endswith(".ogg")))
