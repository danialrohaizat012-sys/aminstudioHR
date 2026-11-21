# Audit Amin Studio HR (21 November 2026)

Skop: app Flutter dalam repo ini (Android, iOS, web PWA di Vercel). Audit meliputi ciri, UI/UX dan keselamatan, berdasarkan kod, ujian automatik dan percubaan di pelayar pada saiz telefon.

## 1. Kajian: apa yang biasa ada dalam HR app SME

| Kategori | Amalan biasa | Sumber |
|---|---|---|
| Layan diri pekerja | Mohon cuti, tuntutan, lihat slip gaji, kemas kini butiran, dari telefon | [Lattice](https://lattice.com/articles/small-business-hr-software), [Gusto](https://gusto.com/resources/guides/best-hr-software-small-business), [TalentHR](https://www.talenthr.io/blog/hr-apps) |
| Rekod & dokumen | Rekod pekerja berpusat, dokumen disulitkan semasa disimpan dan dihantar | [UKG](https://www.ukg.com/for-llms/learn/article-library/hr-leaders/hr-guide-how-choose-best-hr-software-features-your-organization), [Faqtic](https://erzbmzxtdjinuivizctx.supabase.co/functions/v1/render-markdown/blog/top-hr-software-features) |
| Malaysia | Cuti, kehadiran dan tuntutan terus ke gaji; KWSP, PERKESO, SIP, PCB, HRDF; Borang EA; CP39 | [Swingvy](https://www.swingvy.com/blog-my/choose-hr-software-hr-system-guide), [Byte HR](https://byte-hr.com/my/blog/top-hr-software-malaysia), [Employment Hero](https://employmenthero.com/my/hr-software/) |
| Kehadiran mudah alih | GPS + geofence, selfie (lebih baik dengan liveness), sekat lokasi palsu, jejak audit, notis persetujuan, laluan sandaran bila gagal | [greytHR](https://www.greythr.com/employee-mobile-app/answers/Z2EA7vGySRep0uj16KdRYw), [Talenta](https://www.talenta.co/en/features/liveness-validation), [Easywork](https://easywork.freshdesk.com/support/solutions/articles/44001902074-how-easywork-against-employees-cheating-in-attendance), [UEA paper](https://ueaeprints.uea.ac.uk/93712/1/Paper_104_Fraud_Mitigation_in_Attendance_Monitoring_Systems.pdf) |
| Kawalan pengurus | Kawal akses, rekod tepat, uji pandangan pekerja dan admin | [HiBob](https://www.hibob.com/hr-tools/how-to-choose-hr-software-small-business-checklist/) |

Kebanyakan sumber ialah blog vendor; dakwaan produk tidak disahkan secara bebas.

## 2. Keselamatan

| # | Penemuan | Keterukan | Status |
|---|---|---|---|
| S1 | Sesiapa boleh log masuk sebagai mana-mana akaun (termasuk pengurus) tanpa kata laluan | Kritikal | **Dibaiki**: PIN 6 digit, hash SHA-256 bergaram per akaun, PIN lemah (111111, 123456) ditolak |
| S2 | Tiada had cubaan log masuk | Tinggi | **Dibaiki**: 5 cubaan salah, akaun dikunci 5 minit |
| S3 | `saveEmployee`, `postAnnouncement`, `updateSettings`, `setOffice` tidak semak peranan admin dalam kod | Tinggi | **Dibaiki**: semua tindakan pengurus disemak dalam `HrStore`, bukan hanya disorok di skrin |
| S4 | Pengurus boleh meluluskan permohonan sendiri | Sederhana | **Dibaiki**: disekat |
| S5 | Tiada jejak audit untuk perubahan gaji, kelulusan, pembetulan kehadiran | Tinggi | **Dibaiki**: Log audit (siapa, apa, bila, nilai lama → baru), 500 rekod terkini, boleh dicari |
| S6 | Borang pekerja boleh menimpa PIN/persetujuan | Sederhana | **Dibaiki**: kelayakan dan persetujuan dikekalkan semasa simpan |
| S7 | Telefon yang ditinggalkan kekal log masuk | Sederhana | **Dibaiki**: log keluar automatik selepas 10 minit tanpa sentuhan |
| S8 | Gaji, No. KP dan akaun bank terpapar terus | Rendah | **Dibaiki**: disorok sehingga pengurus tekan "Tunjuk" |
| S9 | Lokasi palsu (mock GPS) diterima | Tinggi | **Dibaiki**: Android `isMocked` dan ketepatan 0 m disekat |
| S10 | Punch tanpa lokasi | Tinggi | **Dibaiki** (versi sebelum): disekat di skrin dan di store |
| S11 | Tiada notis privasi untuk GPS dan selfie (PDPA 2010) | Sederhana | **Dibaiki**: notis dan persetujuan sebelum punch pertama, masa persetujuan direkod |
| S12 | Header keselamatan web tiada | Rendah | **Dibaiki**: HSTS, `X-Frame-Options: DENY`, `nosniff`, `Referrer-Policy`, `Permissions-Policy` (lokasi dan kamera untuk app ini sahaja) |
| S13 | Input tidak dihadkan (gaji, tuntutan, jam OT) | Rendah | **Dibaiki**: had nilai di borang dan di store |
| **R1** | **Semua data (termasuk selfie, gaji, hash PIN) disimpan dalam peranti tanpa penyulitan, dan setiap peranti ada salinan sendiri** | **Kritikal untuk guna sebenar** | **Belum**: perlu backend. Selagi tiada backend, semakan peranan hanya melindungi daripada pengguna biasa, bukan orang yang boleh baca storan pelayar |
| R2 | Selfie tiada semakan liveness/padanan muka | Sederhana | Belum: perlu perkhidmatan pengecaman muka |
| R3 | Pengesanan lokasi palsu di iOS dan web terhad (pelayar tidak dedahkan `isMocked`) | Sederhana | Belum: perlu app natif + semakan pelayan (cth. IP, Wi-Fi kedai) |
| R4 | Content-Security-Policy belum ditetapkan | Rendah | Belum: perlu diuji dengan muatan CanvasKit/fon Flutter |
| R5 | Pengekalan data (berapa lama selfie disimpan) belum ditetapkan | Rendah | Belum: tetapkan polisi, cth. padam selfie selepas 90 hari |

## 3. Ciri

| # | Jurang | Status |
|---|---|---|
| F1 | Pemilik tiada peringatan tarikh penting | **Ditambah**: tamat percubaan, tamat kontrak, hari jadi (dari No. KP), ulang tahun kerja |
| F2 | Tiada pandangan cuti akan datang | **Ditambah**: "Cuti 14 hari akan datang" di dashboard |
| F3 | Tuntutan tanpa bukti resit | **Ditambah**: gambar resit, pengurus boleh besarkan semasa kelulusan |
| F4 | Tiada amaran had OT (Akta Kerja: 104 jam sebulan) | **Ditambah**: di borang OT dan semasa kelulusan |
| F5 | Tersilap lulus/tolak tidak boleh diundur | **Ditambah**: butang "Batal" pada notifikasi, direkod dalam log audit |
| F6 | Tarikh tamat percubaan/kontrak tiada dalam rekod | **Ditambah**: medan baharu (lalai 3 bulan percubaan untuk pekerja baharu) |
| F7 | PWA: ikon iPhone dapat sudut hitam; tiada ajakan pasang | **Dibaiki**: ikon `apple-touch-icon` penuh, banner "Pasang" (Android/desktop) dan panduan Kongsi → Add to Home Screen (iOS) |
| F8 | Backend, log masuk berpusat, notifikasi tolak | Belum: langkah seterusnya |
| F9 | Eksport fail bank, CP39, Borang EA dalam app Flutter (ada dalam prototaip web) | Belum |
| F10 | Jadual syif / roster, HRDF, kemas kini butiran oleh pekerja | Belum |

## 4. UI/UX

| # | Penemuan | Status |
|---|---|---|
| U1 | Kad punch melimpah pada telefon sempit | **Dibaiki** (versi sebelum) |
| U2 | Log masuk tanpa pengesahan terasa seperti demo | **Dibaiki**: pad PIN dengan titik, mesej cubaan berbaki, status "Cipta PIN" dan "dikunci" pada senarai |
| U3 | Sebab butang punch kelabu tidak jelas | **Dibaiki** (versi sebelum): mesej di bawah butang |
| U4 | Tiada cara undur tindakan kelulusan | **Dibaiki**: snackbar dengan "Batal" |
| U5 | Gaji terdedah kepada orang di sebelah | **Dibaiki**: disorok secara lalai |
| U6 | Peringatan penting tersorok | **Dibaiki**: kad Peringatan di dashboard |

## 5. Ujian

- `flutter analyze`: tiada isu.
- `flutter test`: 27 ujian lulus, termasuk PIN (hash, kunci, PIN lemah), sekatan peranan, kelulusan sendiri, log audit dan undur, lokasi palsu, peringatan, dan No. KP → tarikh lahir.
- Pelayar (Chromium, saiz Pixel 7 dan iPhone 13): log masuk PIN, banner pasang iOS, notis privasi, dashboard pengurus. Kamera sebenar dan peranti Android/iOS sebenar belum diuji.

## 6. Cadangan seterusnya (ikut keutamaan)

1. **Backend (Supabase atau Firebase)**: log masuk sebenar, data berpusat, peraturan akses di pelayan (Row Level Security), storan selfie dan resit yang disulitkan. Ini menutup R1 dan membolehkan pengurus nampak punch dari semua telefon.
2. **Notifikasi tolak** bila permohonan diluluskan atau slip keluar.
3. **Liveness selfie** dan semakan Wi-Fi kedai sebagai lapisan kedua anti-penipuan.
4. **Eksport**: fail bank, CP39, Borang EA, laporan kehadiran bulanan (CSV/PDF).
5. **Polisi pengekalan data** dan CSP.

---

# Audit ke-2: fungsi, aliran dan UI/UX (21 November 2026)

## Pepijat aliran yang dibaiki

| # | Penemuan | Kesan | Pembaikan |
|---|---|---|---|
| A1 | Pengurus menekan Lulus pada permohonan sendiri: sistem menolak secara senyap tetapi skrin tunjuk "diluluskan" | Mesej palsu, permohonan tersangkut | `decide()` pulangkan sebab; butang diganti mesej "Pengurus lain perlu membuat keputusan" |
| A2 | Baki cuti tidak tolak cuti yang masih menunggu | Pekerja boleh mohon melebihi kelayakan | Baki dalam borang dan semakan store kira permohonan menunggu |
| A3 | "Set semula data demo" memadam semua data tanpa pengesahan | Kehilangan data tidak sengaja | Dialog pengesahan |
| A4 | Tiada cara menambah cuti umum, sedangkan kiraan cuti/kehadiran bergantung padanya | Hari cuti umum dikira hari bekerja / "tiada rekod" | Urus cuti umum (tarikh + nama) di Tetapan syarikat |
| A5 | Tiada cara melantik pengurus kedua | Permohonan pengurus tidak boleh diluluskan sesiapa | Suis "Pengurus (akses HR)" dalam borang pekerja; tidak boleh tarik akses sendiri |
| A6 | Penolakan tanpa sebab, pekerja tidak dimaklumkan | Pekerja keliru | Sebab wajib ditulis semasa tolak, dipapar kepada pekerja; lencana pada tab Mohon untuk keputusan baharu |
| A7 | Pengumuman tidak boleh dipadam | Maklumat lapuk kekal | Padam dengan pengesahan, direkod dalam log audit |

## Ciri tambahan

- **Tempoh khidmat:** dalam senarai pekerja (susun paling lama/paling baru), purata dan paling lama, ulang tahun kerja seterusnya, dan amaran bila kelayakan cuti di bawah minimum Akta Kerja untuk tempoh khidmat tersebut (8/12/16 hari tahunan, 14/18/22 hari sakit).
- **Gambar profil:** pekerja tukar sendiri (kamera/galeri); pengurus boleh tukar untuk sesiapa (direkod dalam log audit).
- **Payroll:** bonus, komisen, elaun tambahan dan potongan lain bagi setiap bulan (draf sahaja, dikunci selepas dimuktamadkan); slip gaji PDF; PDF ringkasan gaji dengan senarai bayaran bank dan caruman berkanun; ringkasan tahunan per pekerja untuk Borang EA (skrin + PDF).
- Getaran (haptic) bila punch berjaya.

## Ujian

38 ujian lulus (sebelum ini 29), termasuk penjanaan PDF dan semua pembaikan A1–A7.

## Masih terbuka

- Semua perkara R1–R5 dalam audit pertama (backend, liveness, CSP, pengekalan data).
- PCB untuk bonus menggunakan kaedah bulanan ringkas; kaedah saraan tambahan LHDN memberi nilai berbeza.
- Potongan gaji untuk hari tiada rekod tidak dibuat secara automatik (keputusan HR).
