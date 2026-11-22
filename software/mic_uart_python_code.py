import time
import serial
import matplotlib.pyplot as plt
from collections import deque

SERIAL_PORT = 'COM3'  # Kendi COM portunuzu yazın
BAUD_RATE = 115200

# Ekranda aynı anda görünecek nokta sayısı (250 nokta @ 500 Hz = son 0.5 saniye)
BUFFER_SIZE = 250
data_buffer = deque([0] * BUFFER_SIZE, maxlen=BUFFER_SIZE)

try:
    ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=0.05)
    ser.reset_input_buffer() # Başlangıçtaki eski/bayat verileri temizle
    print(f"Bağlandı: {SERIAL_PORT} @ {BAUD_RATE} Baud")
except Exception as e:
    print(f"Bağlantı Hatası: {e}")
    exit()

# Grafik Kurulumu
plt.style.use('dark_background') # Daha net ve kontrastlı görünüm
fig, ax = plt.subplots(figsize=(9, 4.5))
line, = ax.plot(range(BUFFER_SIZE), list(data_buffer), color='#00FFCC', linewidth=1.8)

# Ses genliği 0-375 arası ama 8-bit gönderimde 0-187 aralığında salınır
ax.set_ylim(0, 200)
ax.set_xlim(0, BUFFER_SIZE - 1)
ax.set_title("FPGA Gerçek Zamanlı Ses Genliği (Sıfır Gecikme)", fontsize=12)
ax.set_xlabel("Zaman (Son 0.5 Saniye)")
ax.set_ylabel("Ses Genliği")
ax.grid(True, linestyle='--', alpha=0.3)

plt.show(block=False)
fig.canvas.draw()
background = fig.canvas.copy_from_bbox(ax.bbox)

try:
    while plt.fignum_exists(fig.number):
        bytes_waiting = ser.in_waiting
        if bytes_waiting > 0:
            # Eğer PC tarafı anlık yavaşlarsa eski yığılmayı at, sadece en güncel veriyi al
            if bytes_waiting > 100:
                ser.read(bytes_waiting - 20)
            
            raw_bytes = ser.read(ser.in_waiting)
            for b in raw_bytes:
                data_buffer.append(b)

            # Hızlı Çizim (Blitting - tüm pencereyi değil sadece çizgiyi yeniler)
            fig.canvas.restore_region(background)
            line.set_ydata(list(data_buffer))
            ax.draw_artist(line)
            fig.canvas.blit(ax.bbox)
            fig.canvas.flush_events()

        time.sleep(0.002)

except KeyboardInterrupt:
    print("Durduruldu.")

finally:
    if 'ser' in locals() and ser.is_open:
        ser.close()