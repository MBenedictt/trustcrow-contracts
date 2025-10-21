# TrustCrow  
**Peer-to-Peer Escrow Platform for Freelancers, Powered by Smart Contracts**

TrustCrow adalah platform **peer-to-peer escrow berbasis blockchain** yang memastikan setiap transaksi antara **freelancer dan klien** berlangsung **aman, transparan, dan adil tanpa perantara**.  
Setiap proyek dibuat dalam bentuk **Quotation Contract**, di mana pembayaran disimpan di **escrow otomatis (smart contract)** dan dirilis secara bertahap sesuai progres milestone yang disetujui klien.

---

## Latar Belakang  

Freelancer di Indonesia masih sering bertransaksi manual melalui WhatsApp atau transfer langsung tanpa jaminan pembayaran.  
Masalah seperti **klien ghosting**, **pembatalan sepihak**, dan **penipuan proyek** masih sering terjadi.  

Di sisi lain, platform freelance global seperti **Upwork** atau **Fiverr** mengenakan **fee tinggi (10–20%)** dan tetap bergantung pada **pihak sentral**.  

TrustCrow hadir sebagai solusi **peer-to-peer escrow service** yang dijalankan sepenuhnya oleh **smart contract di blockchain**, tanpa pihak ketiga.

---

## Arsitektur Kontrak  

### `Quotation.sol`  
Kontrak utama yang mewakili satu proyek antara **freelancer (seller)** dan **klien (buyer)**.  

**Fitur utama:**  
- Freelancer membuat *quotation* berisi milestone, deadline, dan persentase pembayaran.  
- Klien menyetor dana (ETH native / ERC20) ke escrow.  
- Dana disimpan aman oleh smart contract hingga milestone disetujui.  
- **Auto-release:** jika klien tidak merespons dalam jangka waktu tertentu, pembayaran otomatis dilepas ke freelancer.  
- **Refund:** jika freelancer tidak mengirim hasil sebelum tenggat waktu, dana dapat diklaim kembali oleh klien.  
- Seluruh transaksi transparan dan terverifikasi on-chain.

---

### `QuotationFactory.sol`  
Kontrak *factory* yang digunakan untuk **membuat instance Quotation baru**.  
Digunakan oleh platform TrustCrow untuk mengelola semua proyek dengan mudah.

**Fitur utama:**  
- Mendeploy kontrak `Quotation` baru untuk setiap proyek.  
- Mencatat semua quotation milik setiap **freelancer (seller)** dan **klien (buyer)**.  
- Memungkinkan pencarian riwayat transaksi atau quotation sebelumnya.  
- Dijalankan oleh admin (owner) sebagai kontrol awal platform.

---

## Workflow Singkat  

1. **Freelancer membuat quotation**  
   Menentukan milestone, deadline, dan persentase pembayaran.  
2. **Klien menyetor dana ke escrow contract**  
   Dana terkunci aman di blockchain.  
3. **Freelancer mengerjakan milestone pertama**  
   Hasil dikirim lewat kanal komunikasi (WhatsApp, email, dsb).  
4. **Klien menyetujui milestone**  
   Smart contract otomatis merilis pembayaran ke freelancer.  
5. **Auto-release & refund logic**  
   Jika klien tidak merespons atau freelancer tidak submit, kontrak mengeksekusi aturan otomatis.
