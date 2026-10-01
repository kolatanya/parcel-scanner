/* ecomFLEX customer screens (panel.html, signup.html): Turkish <-> English.
   The pages are written in Turkish. When the customer picks EN, this swaps the
   text they can see (and tooltips, placeholders, pop-up questions, Excel headings)
   for English, and puts the Turkish back when they pick TR. The choice is kept in
   this browser. Customer data (product names, messages, notes) is never sent anywhere.
   Elements marked data-noi18n are left alone (chat messages, codes). */
(function(){
"use strict";
var KEY='ecomflex:lang';
var lang='tr';
try{ if(localStorage.getItem(KEY)==='en') lang='en'; }catch(e){}

/* ---------- exact phrases ---------- */
var D={
/* menu, page names, shell */
'Genel Bakış':'Overview','Tanımlar':'Setup','Ürünler':'Products','Alıcılar':'Recipients','Operasyonlar':'Operations','Stok':'Stock',
'Gönderiler':'Shipments','Gelen Kargo':'Inbound Deliveries','Hizmet Talepleri':'Service Requests','Hizmet Satın Al':'Buy Services',
'Muhasebe':'Accounts','Bakiye':'Balance','Ödeme Bildirimleri':'Payment Notices','Faturalar':'Invoices','Aylık Özet':'Monthly Summary',
'Araçlar':'Tools','araçlar':'tools','Fiyat Listesi':'Price List','Belgeler':'Documents','Depo Adresim':'My Warehouse Address','Destek':'Support',
'Destek Talepleri':'Support Tickets','Mesajlar':'Messages','Duyurular':'Announcements','Bildirimler':'Notifications','Hesabım':'My account',
'Menü':'Menu','Çıkış yap':'Sign out','Müşteri Paneli':'Customer Panel','Müşteri Paneli — ecomFLEX':'Customer Panel — ecomFLEX',
'aktif şirket':'active company','müşteri':'customer','bakiye':'balance','panel':'panel','ana veriler':'master data','hizmetler':'services',
'Yükleniyor…':'Loading…','Merhaba':'Hello','Günaydın':'Good morning','İyi günler':'Good afternoon','İyi akşamlar':'Good evening','İyi geceler':'Good night',
'Kapat':'Close','Vazgeç':'Cancel','Kaydet':'Save','Sil':'Delete','Düzenle':'Edit','Geri':'Back','Devam':'Continue','Tamam':'OK','Ara':'Search',
'Temizle':'Clear','Görüntüle':'View','İndir':'Download','Kopyala':'Copy','Kopyalandı':'Copied','Kopyalanamadı':'Could not copy','Copied':'Copied',
'Tekrar dene':'Try again','Seçin…':'Choose…','Tümü':'All','Tümünü gör':'See all','Detaylar':'Details','Sayfa başına':'Per page','Artır':'Increase','Azalt':'Decrease',
'0 kayıt':'0 records','Kayıt bulunamadı.':'No records found.','Aramanızla eşleşen kayıt yok.':'Nothing matches your search.','Yüklenemedi.':'Could not load.',
'Bilgiler yüklenemedi. Lütfen tekrar deneyin.':'Could not load the details. Please try again.','Bu alan gerekli.':'This field is required.',
'Lütfen işaretli alanları düzeltin.':'Please correct the marked fields.','Lütfen işaretli alanları doldurun.':'Please fill in the marked fields.',
'Gönderiliyor…':'Sending…','Gönder':'Send','Gönderilemedi.':'Could not send.','Gönderilemedi. Lütfen tekrar deneyin.':'Could not send. Please try again.',
'Gönderilemedi · tekrar dene':'Not sent · try again','Tekrar göndermek için dokunun':'Tap to send again','Dosya açılamadı.':'Could not open the file.',
'Dosya okunamadı.':'Could not read the file.','Excel indir':'Download Excel','Excel dosyası hazırlanamadı.':'Could not prepare the Excel file.',
'Excel dosyası hazırlanamadı. Lütfen tekrar deneyin.':'Could not prepare the Excel file. Please try again.','Grafik yüklenemedi.':'Could not load the chart.',
'Sunucuya ulaşılamıyor. Lütfen biraz sonra tekrar deneyin.':'Cannot reach the server. Please try again shortly.',
'Sunucuya ulaşılamıyor. Lütfen daha sonra tekrar deneyin.':'Cannot reach the server. Please try again later.',
'Ayarlar tamamlanmamış (ecomflex-config.js).':'Settings are not complete (ecomflex-config.js).',
'Bugün':'Today','Dün':'Yesterday','yeni':'new','yok':'none','Diğer':'Other','Genel':'General','Toplam':'Total','Siz':'You',
/* sign-in */
'Kayıt sırasında size verilen 8 haneli kodla giriş yapın.':'Sign in with the 8-character code you were given when you signed up.',
'Giriş kodunuz':'Your sign-in code','Giriş yap':'Sign in','Giriş yapılıyor…':'Signing in…','Giriş yapın':'Sign in',
'E-posta ile giriş yap':'Sign in with email','E-posta ve şifre ile giriş yap':'Sign in with email and password','E-posta adresi':'Email address',
'Şifre':'Password','E-posta adresimi bu cihazda hatırla':'Remember my email on this device','E-posta veya şifre hatalı.':'Wrong email or password.',
'Lütfen 8 haneli kodunuzu yazın.':'Please enter your 8-character code.','Lütfen kodunuzu yazın.':'Please enter your code.','Lütfen şifrenizi yazın.':'Please enter your password.',
'Bu kod tanınmadı. Kodunuzu kontrol edin veya info@ecomflex.co.uk adresine yazın.':'This code was not recognised. Check it, or email info@ecomflex.co.uk.',
'Çok fazla deneme yapıldı. Birkaç dakika sonra tekrar deneyin.':'Too many attempts. Please try again in a few minutes.',
'Giriş yapılamadı. Lütfen tekrar deneyin.':'Could not sign in. Please try again.','Henüz müşterimiz değil misiniz?':'Not a customer yet?',
'Hesabınız bulunamadı':'Account not found','adresiyle kayıtlı bir müşteri hesabı bulamadık.':': we could not find a customer account for this email address.',
'Yeni müşteriyseniz kayıt formunu doldurun. Kayıtlı olduğunuzu düşünüyorsanız':'If you are a new customer, fill in the sign-up form. If you think you are already registered, email',
'adresine yazın.':'.','Farklı bir hesapla giriş yap':'Sign in with a different account','Bağlantı kurulamadı':'Could not connect',
'Hesap bilgileri alınamadı. Lütfen sayfayı yenileyin.':'Could not get your account details. Please refresh the page.',
/* first payment */
'Hesabınızı açmak için ilk ödemenizi yapın':'Make your first payment to open your account',
'İlk ödemeniz hesabımıza ulaştığında tüm özellikler açılır. Adım adım anlatıyoruz.':'Everything opens once your first payment reaches our account. We will guide you step by step.',
'İlk ödememi yap':'Make my first payment','son bir adım':'one last step','İlk ödemenizi yapın':'Make your first payment',
'Hesabınız hazır. İlk ödemeniz hesabımıza ulaştığında gönderi, gelen kargo, hizmet talepleri ve tüm diğer özellikler açılır.':'Your account is ready. Once your first payment reaches our account, shipments, inbound deliveries, service requests and everything else open up.',
'Banka havalesi · en az £50 · adım adım anlatıyoruz':'Bank transfer · at least £50 · we guide you step by step',
'Güvenli ödeme.':'Secure payment.','Paranız Ecomflex Ltd adına kayıtlı İngiltere şirket hesabımıza gider.':'Your money goes to our UK company account in the name of Ecomflex Ltd.',
'Her kuruş görünür.':'Every penny is visible.','Yüklediğiniz ve harcadığınız her tutar Bakiye sayfanızda satır satır listelenir.':'Every amount you pay in and spend is listed line by line on your Balance page.',
'Takıldığınız yerde yazın.':'Stuck? Write to us.','Mesajlar bölümünden ekibimize doğrudan ulaşabilirsiniz.':'You can reach our team directly in Messages.',
'ödeme bildirimi alındı':'payment notice received','Ödemeniz kontrol ediliyor':'We are checking your payment','Bildirimlerimi gör':'See my notices',
'Adımları tekrar gör':'See the steps again','İlk ödeme':'First payment','Dört kısa adım. Takılırsanız Mesajlar bölümünden bize yazın.':'Four short steps. If you get stuck, write to us in Messages.',
'Havale':'Transfer','Açıklama':'Reference','Bildirim':'Notify','1. Bize banka havalesi yapın':'1. Send us a bank transfer',
'Bankanızın uygulamasından veya şubesinden aşağıdaki hesaba havale yapın. Bu hesap Ecomflex Ltd adına kayıtlı İngiltere şirket hesabımızdır.':'Use your banking app or branch to send a transfer to the account below. It is our UK company account in the name of Ecomflex Ltd.',
'Hesap bilgilerini kopyala':'Copy account details','En az £50 gönderin.':'Send at least £50.','Hesabımıza ulaşan tutarın tamamı bakiyenize eklenir.':'The full amount that reaches our account is added to your balance.',
'Güvenliğiniz için:':'For your safety:','Ödemeyi yalnızca burada gösterilen hesaba yapın. E-posta veya telefonla farklı bir hesap bilgisi gelirse ödeme yapmadan önce Mesajlar bölümünden bize sorun.':'Only pay into the account shown here. If you receive different account details by email or phone, ask us in Messages before paying.',
'Kartla ödemeyi tercih ederim':'I would rather pay by card','2. Açıklamaya şirket adınızı yazın':'2. Put your business name in the reference',
'ÖNEMLİ':'IMPORTANT','Havale açıklamasına (referans) mutlaka şunu yazın:':'Always write this in the payment reference:',
'Açıklama kopyalandı':'Reference copied','Böylece paranın kime ait olduğunu anlar ve bakiyeyi doğru hesaba ekleriz. Açıklaması olmayan ödemeleri eşleştirmek gecikebilir.':'This is how we know whose money it is and add the balance to the right account. Payments without a reference can take longer to match.',
'Şirket adınız':'Your company name','Müşteri kodunuz':'Your customer code',
'Bankanız açıklamayı kısaltırsa en azından müşteri kodunuzu yazın; kod tek başına da yeterlidir.':'If your bank shortens the reference, write at least your customer code; the code on its own is enough.',
'3. Ödemenizi bize bildirin':'3. Tell us you have paid','Havaleyi gönderdikten sonra bize haber verin. Ödemenizi bekler, hesabımıza geçtiğinde hemen onaylarız.':'Once you have sent the transfer, let us know. We watch for it and confirm it as soon as it reaches our account.',
'Gönderdiğiniz tutar (£)':'Amount you sent (£)','Lütfen gönderdiğiniz tutarı yazın (en az £1).':'Please enter the amount you sent (at least £1).','Gönderim tarihi':'Date sent',
'Havale açıklaması':'Payment reference','Havalede yazdığınız açıklama. Ödemenizi eşleştirmemize yardımcı olur.':'The reference you used on the transfer. It helps us match your payment.',
'Henüz havale yapmadıysanız bu pencereyi kapatabilirsiniz; adımlara ana sayfadan istediğiniz zaman dönebilirsiniz.':'If you have not sent the transfer yet you can close this window; you can come back to these steps from the home page at any time.',
'Bildiriminiz alındı':'Notice received','Bundan sonrası bizde:':'We take it from here:','Para hesabımıza ulaştığında ekibimiz kontrol eder.':'When the money reaches our account, our team checks it.',
'Tutarı bakiyenize ekleriz; zil simgesinde bildirim görürsünüz.':'We add it to your balance and you will see a notification under the bell.',
'Hesabınız açılır ve gönderi, gelen kargo ve hizmet taleplerinizi oluşturabilirsiniz.':'Your account opens and you can create shipments, inbound deliveries and service requests.',
'Havale bilgilerini aldım':'I have the bank details','Açıklamayı yazdım':'I have written the reference','Ödemeyi bildir':'Send payment notice',
/* dashboard */
'Stoğunuzun, bakiyenizin ve açık depo işlerinizin özeti.':'A summary of your stock, balance and open warehouse work.','toplam stok':'total stock','hasarlı stok':'damaged stock',
'aktif ürün':'active products','bu ay giriş yok':'nothing in this month','ayrı tutuluyor':'kept separate','hasarlı ürün yok':'no damaged items',
'Hızlı işlemler':'Quick actions','Sık kullandığınız işlemlere tek tıkla ulaşın.':'One click to the things you do most.','Yeni gönderi':'New shipment',
'Müşterinize depodan ürün gönderin.':'Send a product from the warehouse to your customer.','Gelen kargo bildir':'Announce a delivery','Depomuza ürün gönderdiğinizi bildirin.':'Tell us you are sending products to our warehouse.',
'Hizmet talebi':'Service request','İade, kargo yönlendirme veya FBA hazırlık.':'Returns, parcel forwarding or FBA prep.','Bakiye yükle':'Top up balance','Kartla veya banka havalesiyle.':'By card or bank transfer.',
'Ödeme bildir':'Report a payment','Yaptığınız havaleyi bize bildirin.':'Tell us about a transfer you made.','Destek talebi':'Support ticket','Ekibimize soru sorun.':'Ask our team a question.',
'Hesap özeti':'Account summary','Güncel bakiye ve hesap bilgileri.':'Current balance and account details.','Kullanılabilir bakiye':'Available balance','Geçen aya göre harcama':'Spending vs last month',
'Bu ay yüklenen':'Paid in this month','Bu ay harcanan':'Spent this month','Depo adresiniz':'Your warehouse address','Ürünlerinizi bu adrese gönderin.':'Send your products to this address.',
'Adresi kopyala':'Copy address','Depo adresi kopyalandı':'Warehouse address copied','Depo durumu':'Warehouse status','Stokta olan ürün':'Products in stock','Azalan stok':'Running low',
'Tükenen ürün':'Out of stock','Hasarlı stok':'Damaged stock','Açık işler':'Open work','Ekibimizin üzerinde çalıştığı işler.':'Work our team is doing for you.',
'Hazırlanan gönderi':'Shipments being prepared','Beklenen gelen kargo':'Expected deliveries','Açık hizmet talebi':'Open service requests','Etiket bekleyen FBA':'FBA waiting for labels',
'Bekleyen ödeme bildirimi':'Payment notices waiting','Okunmamış destek yanıtı':'Unread support replies','Bekleyen iş yok.':'No open work.','Hasarlı ürün yok.':'No damaged items.',
'Hasarlı olarak ayrılan ürünleriniz.':'Your items set aside as damaged.','Eğilimler':'Trends','Son 12 ayın stok ve para hareketleri.':'Stock and money movements over the last 12 months.',
'Stok hareketi':'Stock movement','Para hareketi':'Money movement','Son hareketler':'Recent activity','Henüz hareket yok.':'No activity yet.','Henüz duyuru yok.':'No announcements yet.',
'Giriş':'In','Çıkış':'Out','Yüklenen':'Paid in','Harcanan':'Spent',
/* products */
'Depomuzda tuttuğumuz ürünlerinizin listesi. Gönderi ve gelen kargo formlarında ürünleri buradan seçersiniz.':'The list of your products we keep in our warehouse. You pick products from here in the shipment and delivery forms.',
'Ürün ekle':'Add product','Toplu yükle':'Bulk upload','Ürünlerde ara…':'Search products…','Aktif':'Active','Pasif':'Inactive','Aktif (varsayılan)':'Active (default)',
'Henüz ürün yok. “Ürün ekle” veya “Toplu yükle” ile başlayın.':'No products yet. Start with “Add product” or “Bulk upload”.','Ürünler yüklenemedi.':'Could not load products.',
'Bu filtrelere uyan ürün yok.':'No products match these filters.','Ürünü düzenle':'Edit product','Ürünü ekle':'Add the product','SKU / ürün kodu (FNSKU)':'SKU / product code (FNSKU)',
'Ürünün üzerindeki kod. Gönderi ve gelen kargo formlarında bu kodu kullanırsınız.':'The code on the product. You use it in the shipment and delivery forms.','SKU değiştirilemez.':'The SKU cannot be changed.',
'Ürün adı':'Product name','ASIN (isteğe bağlı)':'ASIN (optional)','Barkod (isteğe bağlı)':'Barcode (optional)','Barkod':'Barcode','Uyarı eşiği':'Low-stock alert',
'Uyarı eşiği: stok bu sayıya düştüğünde ürün “azalan” olarak işaretlenir. 0 = uyarı yok.':'Low-stock alert: when stock falls to this number the product is marked “running low”. 0 = no alert.',
'Stok bu sayıya düştüğünde ürün “azalan” olarak işaretlenir. 0 = uyarı yok.':'When stock falls to this number the product is marked “running low”. 0 = no alert.',
'Yeni ürün, stok miktarı 0 ile eklenir.':'A new product is added with stock 0.','Lütfen SKU yazın.':'Please enter the SKU.','Lütfen ürün adını yazın.':'Please enter the product name.',
'Ürün eklendi.':'Product added.','Ürün güncellendi.':'Product updated.','Ürün aktif yapıldı.':'Product made active.','Ürün pasif yapıldı.':'Product made inactive.','Aktif yap':'Make active','Pasif yap':'Make inactive',
'Amazon’da aç':'Open on Amazon','Toplu ürün yükle':'Bulk upload products','Excel veya Google Sheets’ten kopyalayıp yapıştırın ya da dosya seçin.':'Copy and paste from Excel or Google Sheets, or choose a file.',
'Sütun sırası:':'Column order:','SKU · Ürün adı · ASIN · Barkod':'SKU · Product name · ASIN · Barcode','. Son iki sütun isteğe bağlıdır.':'. The last two columns are optional.',
'. Var olan ürünlerde boş bırakılan bilgiler silinmez; stok miktarları değişmez.':'. For existing products, empty cells do not delete anything and stock quantities do not change.',
'Excel / CSV dosyası seç':'Choose Excel / CSV file','Şablon indir':'Download template','Ürünleri yükle':'Upload products','Satır bulunamadı.':'No rows found.',
'Örnek ürün':'Sample product','(adsız ürün)':'(unnamed product)','Ürün listeniz boş':'Your product list is empty','sku':'sku','ürün adı':'product name','asin':'asin',
'durum':'status','aktif':'active','pasif':'inactive','Ürün':'Product','ürün':'product','ürünler':'products','Kategori':'Category','Durum':'Status','Tarih':'Date',
/* recipients */
'Sık gönderi yaptığınız alıcıları kaydedin; yeni gönderi oluştururken tek tıkla seçin.':'Save the recipients you ship to often and pick them with one click for a new shipment.',
'Alıcı ekle':'Add recipient','Geçmiş gönderilerden aktar':'Import from past shipments','Alıcılarda ara…':'Search recipients…','Alıcılar yüklenemedi.':'Could not load recipients.',
'Kayıtlı alıcı yok. “Alıcı ekle” ya da “Geçmiş gönderilerden aktar” ile başlayın.':'No saved recipients. Start with “Add recipient” or “Import from past shipments”.',
'Aktarılacak yeni alıcı bulunamadı.':'No new recipients to import.','Alıcıyı düzenle':'Edit recipient','Alıcıyı kaydet':'Save recipient','Alıcı kaydedildi.':'Recipient saved.','Alıcı silindi.':'Recipient deleted.',
'Ad soyad / firma':'Name / company','Kişi / firma':'Person / company','Telefon':'Phone','Adres':'Address','Ülke':'Country','E-posta (isteğe bağlı)':'Email (optional)',
'Posta kodu dahil tam adres.':'Full address including postcode.','Sokak, bina no, şehir, posta kodu':'Street, building no, city, postcode','Birleşik Krallık veya Avrupa’da bir ülke.':'The UK or a country in Europe.',
'Lütfen alıcının adını yazın.':'Please enter the recipient’s name.','Lütfen alıcının açık adresini yazın.':'Please enter the recipient’s full address.','Lütfen geçerli bir telefon yazın.':'Please enter a valid phone number.',
'Lütfen ülkeyi yazın.':'Please enter the country.','Lütfen açık adresi yazın.':'Please enter the full address.','Lütfen alıcıyı yazın.':'Please enter the recipient.','Bu alıcı zaten kayıtlı.':'This recipient is already saved.',
'Aynı alıcıya yeni gönderi':'New shipment to this recipient','alıcı':'recipient','adres':'address','telefon':'phone','ülke':'country','Alıcı':'Recipient',
'Birleşik Krallık':'United Kingdom','Almanya':'Germany','Fransa':'France','Hollanda':'Netherlands','Belçika':'Belgium','İtalya':'Italy','İspanya':'Spain','İrlanda':'Ireland',
'Polonya':'Poland','Avusturya':'Austria','İsveç':'Sweden','Danimarka':'Denmark','Portekiz':'Portugal','Çekya':'Czechia','Romanya':'Romania',
/* stock */
'Depomuzdaki güncel stok miktarlarınız. Miktarlar her gönderide ve teslim alınan her kargoda otomatik güncellenir.':'Your current stock in our warehouse. Quantities update automatically with every shipment and every delivery we receive.',
'Stokta ara…':'Search stock…','Stok yüklenemedi.':'Could not load stock.','Henüz ürününüz yok. Bir gelen kargo bildirin; teslim alındığında burada görünür.':'You have no products yet. Announce a delivery; once received it appears here.',
'Stokta var':'In stock','Azalan':'Running low','Tükendi':'Out of stock','tükendi':'out of stock','Hasarlı var':'Has damaged','Hasarlı yok':'No damage','Hasarlı':'Damaged','hasarlı':'damaged',
'Depoda':'In warehouse','Depo konumu':'Warehouse location','depo konumu':'warehouse location','Depo notu':'Warehouse note','son güncelleme':'last updated','uyarı eşiği':'low-stock alert',
'Uyarı eşiği kaydedildi.':'Low-stock alert saved.','Stok miktarı yalnızca ekibimiz tarafından, teslim alınan kargo ve gönderilere göre güncellenir.':'Only our team changes stock quantities, based on deliveries received and shipments sent.',
'Depodaki toplam adet':'Total units in the warehouse','stok':'stock','stok durumu':'stock status','Stoğunuzdaki ürünler.':'The products in your stock.',
/* shipments */
'Müşterilerinize gönderilecek siparişler. Gönderi yola çıktığında kargo firması ve takip numarası burada görünür.':'Orders to send to your customers. Once a shipment leaves, the courier and tracking number appear here.',
'Gönderi oluştur':'Create shipment','Toplu gönderi':'Bulk shipments','Gönderilerde ara…':'Search shipments…','Gönderiler yüklenemedi.':'Could not load shipments.','Bu tarih aralığında gönderi yok.':'No shipments in this date range.',
'başlangıç tarihi':'start date','bitiş tarihi':'end date','Hazırlanıyor':'Being prepared','hazırlanıyor':'being prepared','Gönderildi':'Sent','gönderildi':'sent',
'Gönderiniz yola çıktı':'Your shipment is on its way','Gönderiniz hazırlanıyor. Yola çıktığında kargo firması ve takip numarası burada görünecek.':'Your shipment is being prepared. Once it leaves, the courier and tracking number will appear here.',
'Takip numarası':'Tracking number','takip numarası':'tracking number','Takip numarası kopyalandı':'Tracking number copied','Takip numarasını kopyala':'Copy tracking number','Kargo firması':'Courier','kargo firması':'courier',
'Gönderi talebi oluştur':'Create shipment request','Kayıtlı alıcı':'Saved recipient','Yeni alıcı — bilgileri aşağıya yazacağım':'New recipient — I will type the details below',
'Bu alıcıyı Alıcılar listeme kaydet':'Save this recipient to my Recipients','Alıcı adı':'Recipient name','alıcı adı':'recipient name','Adet':'Quantity','adet':'units',
'Adet en az 1 olmalıdır.':'Quantity must be at least 1.','Ürün seçin…':'Choose a product…','Listede yok — ürün adını yazacağım':'Not in the list — I will type the product name',
'Listede yok — SKU yazacağım':'Not in the list — I will type the SKU','Lütfen bir ürün seçin.':'Please choose a product.','Lütfen ürünü seçin.':'Please choose the product.',
'Bu üründen depoda stok yok.':'There is no stock of this product in the warehouse.','Sipariş numarası (isteğe bağlı)':'Order number (optional)','Amazon / eBay sipariş numarası.':'Amazon / eBay order number.',
'Pazar yeri (isteğe bağlı)':'Marketplace (optional)','Pazar yeri':'Marketplace','Not (isteğe bağlı)':'Note (optional)','not (isteğe bağlı)':'note (optional)','Not':'Note','not':'note',
'Ekibimize iletmek istediğiniz not (isteğe bağlı)':'A note for our team (optional)','Gönderi talebiniz alındı. Hazırlandığında takip numarası burada görünecek.':'Shipment request received. Once it is prepared, the tracking number will appear here.',
'Hesabınız henüz aktif değil. Önce bakiye yükleyin.':'Your account is not active yet. Please top up first.','Excel veya Google Sheets’ten kopyalayıp yapıştırın ya da dosya seçin. Her satır bir gönderi olur.':'Copy and paste from Excel or Google Sheets, or choose a file. Each row becomes one shipment.',
'Alıcı adı · Telefon · Adres · Ülke · SKU · Adet · Sipariş no · Not':'Recipient name · Phone · Address · Country · SKU · Quantity · Order no · Note',
'İlçe/Bölge (County/Region) alanı zorunluysa':'If the County/Region field is required','Gönderileri oluştur':'Create shipments','Yapıştırılan satır bulunamadı.':'No pasted rows found.',
'hazır':'ready','adres eksik':'address missing','alıcı adı eksik':'recipient name missing','telefon geçersiz':'phone not valid','adet geçersiz':'quantity not valid',
'SKU ürün listenizde yok':'SKU is not in your product list','SKU eksik':'SKU missing','Sipariş no':'Order no','sipariş no':'order no','Tutar':'Amount','tutar':'amount',
'Gönderim adresi':'Delivery address','Gönderi':'Shipment','Gönderim':'Shipping','alıcı bilgileri':'recipient details','Takip no':'Tracking no','kargo':'courier',
'Servis tercihi':'Service preference','Tercih edilen servis (isteğe bağlı)':'Preferred service (optional)','En ucuz / En hızlı':'Cheapest / Fastest','Ücret':'Charge','ücret':'charge','Ücret (£)':'Charge (£)',
'Teslim edilemedi':'Could not be delivered','Takipsiz':'Untracked','Takipsiz kargo':'Untracked parcel','Tahmini süre':'Estimated time',
/* inbound */
'Depomuza gönderdiğiniz kargoları önceden bildirin. Teslim alındığında sayılır ve sayılan adet stoğunuza eklenir.':'Tell us in advance about deliveries you send to our warehouse. When received they are counted and the counted quantity is added to your stock.',
'Gelen kargo':'Inbound delivery','gelen kargo':'inbound delivery','Gelen kargo bildirimi':'Delivery announcement','Gelen kargolarda ara…':'Search deliveries…','Gelen kargolar yüklenemedi.':'Could not load deliveries.',
'Henüz gelen kargo bildirimi yok.':'No deliveries announced yet.','Bekleniyor':'Expected','beklenen':'expected','Teslim alındı':'Received','teslim alındı':'received','Kargonuz teslim alındı':'Your delivery has arrived',
'Depomuza gönderdiğiniz kargonun içeriğini bildirin.':'Tell us what is in the delivery you are sending us.','Kargoyu göndermeden önce':'Before sending a delivery, announce it on the',
'Adresin ilk satırına mutlaka şirket adınızı ve birim numaranızı yazın.':'Always put your company name and unit number on the first line of the address.',
'Kargo firması (isteğe bağlı)':'Courier (optional)','Takip numarası (isteğe bağlı)':'Tracking number (optional)','Koli sayısı':'Number of boxes','Koli sayısı (isteğe bağlı)':'Number of boxes (optional)',
'Beklenen varış (isteğe bağlı)':'Expected arrival (optional)','Beklenen tarih':'Expected date','Tahmini varış tarihi':'Estimated arrival date','Gönderen':'Sender','Gönderen / tedarikçi (isteğe bağlı)':'Sender / supplier (optional)',
'kolilerdeki ürünler':'products in the boxes','+ Ürün satırı ekle':'+ Add product line','En az bir ürün satırı doldurun (SKU ve adet).':'Fill in at least one product line (SKU and quantity).','En az 1 koli.':'At least 1 box.',
'Adetler 1 ile 10.000 arasında olmalı.':'Quantities must be between 1 and 10,000.','Gelen kargo bildiriminiz alındı.':'Delivery announcement received.','Satırı sil':'Remove line',
'Kargonuz teslim alındığında sayılacak ve sayılan adet stoğunuza eklenecek.':'When your delivery arrives it will be counted and the counted quantity added to your stock.',
'bildirilen':'declared','sayılan':'counted','Sayılan adet bildirilen adetten farklı. Stoğunuza sayılan adet eklendi. Sorunuz varsa destek talebi oluşturun.':'The counted quantity differs from the declared quantity. The counted quantity was added to your stock. If you have questions, open a support ticket.',
'Giren adet':'Units in','Çıkan adet':'Units out','Toplam adet':'Total units','Ürün çeşidi (SKU)':'Product lines (SKU)','koli':'boxes','SKU veya FNSKU':'SKU or FNSKU','SKU veya barkod':'SKU or barcode',
'Hasarlı geldi':'Arrived damaged','Teslim alınan kargo':'Delivery received',
/* services */
'İade, kargo yönlendirme ve Amazon FBA hazırlık talepleriniz ile ekibimizin yanıtları.':'Your returns, parcel forwarding and Amazon FBA prep requests, with our team’s replies.',
'İade':'Return','İade bildir':'Report a return','Kargo yönlendirme':'Parcel forwarding','Kargo Yönlendirme':'Parcel Forwarding','FBA hazırlık':'FBA prep','FBA Hazırlık':'FBA Prep',
'Yeni iade bildirimi':'New return','Yeni yönlendirme talebi':'New forwarding request','Yeni FBA talebi':'New FBA request','Taleplerde ara…':'Search requests…','Talepler yüklenemedi.':'Could not load requests.',
'Henüz iade bildirimi yok.':'No returns yet.','Henüz yönlendirme talebi yok.':'No forwarding requests yet.','Henüz FBA hazırlık talebi yok.':'No FBA prep requests yet.',
'Müşterinizden depomuza dönecek ürünü bildirin. Sağlam olanlar stoğunuza geri eklenir.':'Tell us about a product coming back from your customer. Items in good condition go back into your stock.',
'İade sebebi':'Reason for return','Lütfen bir sebep seçin.':'Please choose a reason.','Yanlış beden':'Wrong size','Yanlış ürün gönderildi':'Wrong item sent','Ürün beğenilmedi':'Customer did not like it',
'Müşteri vazgeçti':'Customer changed their mind','Gelen takip':'Incoming tracking','Lütfen takip numarasını yazın.':'Please enter the tracking number.',
'Depomuza gelecek bir kargoyu, ulaştığında başka bir adrese yönlendirelim.':'We forward a parcel arriving at our warehouse to another address.','yönlendirilecek adres':'forwarding address','yönlendirilecek':'to forward',
'Kargo yönlendirme talebi':'Forwarding request','Yönlendirilen kargo':'Forwarded parcel','Amazon FBA hazırlığı için':'For Amazon FBA prep, use the','Hedef depo':'Destination warehouse','hedef depo':'destination warehouse',
'Shipment ID':'Shipment ID','shipment id':'shipment id','yeni fnsku':'new fnsku','X002NEWAAA (isteğe bağlı)':'X002NEWAAA (optional)','X001ABCDEF veya 004-LGG-G':'X001ABCDEF or 004-LGG-G',
'Örn. ASIN, koli sayısı veya özel bir isteğiniz':'E.g. ASIN, number of boxes or any special request','Talebi gönder':'Send request','Talebiniz alındı.':'Request received.',
'Kolileriniz hazır. Her koli için Amazon FBA ve taşıyıcı etiketini (PDF) yükleyin.':'Your boxes are ready. Upload the Amazon FBA and carrier label (PDF) for each box.','Etiketleri yükle':'Upload labels',
'Tüm etiketleriniz alındı. Ekibimiz kolilere yapıştırıp talebi kapatacak.':'All your labels are in. Our team will stick them on the boxes and close the request.','etiket':'label',
'etiket bekleniyor':'waiting for labels','etiketler alındı':'labels received','FBA kolileriniz hazır':'Your FBA boxes are ready','Talebi iptal et':'Cancel request','Bu talebi iptal etmek istiyor musunuz?':'Do you want to cancel this request?',
'Talep iptal edildi.':'Request cancelled.','İptal edildi':'Cancelled','iptal edildi':'cancelled','Tamamlandı':'Completed','tamamlandı':'completed','Ekibimizde':'With our team','Ekibimizin notu':'Our team’s note',
'Ekibimiz tarafından işlendi':'Processed by our team','İşlenen iade':'Return processed','Talep':'Request','Talep no':'Request no','talep no':'request no','İşlem':'Action','işlem':'action','işlemler':'actions',
'Durum':'Status','Karar':'Decision','Stoğa eklenen':'Added to stock','İade / hizmet':'Return / service','hizmet':'service','İşlem bekleyen':'Waiting for action','Yazışma':'Conversation','yazışma':'conversation',
/* buy services */
'Hizmet satın al':'Buy services','İhtiyacınız olan hizmetleri seçin ve bakiyenizden ödeyin. Siparişiniz ekibimize anında düşer; tamamlandığında size bildirim gelir.':'Pick the services you need and pay from your balance. Your order reaches our team straight away and you are notified when it is done.',
'Hizmet ara…':'Search services…','Hizmetler yüklenemedi. Lütfen sayfayı yenileyin.':'Could not load services. Please refresh the page.','Şu anda çevrim içi sipariş edilebilen bir hizmet yok. Sorularınız için Mesajlar sayfasından bize yazabilirsiniz.':'There are no services to order online right now. You can write to us on the Messages page.',
'Sipariş özeti':'Order summary','Henüz hizmet seçmediniz. Adet girerek sepete ekleyin.':'You have not picked any services yet. Enter a quantity to add one.','Bakiyeden öde':'Pay from balance',
'Sipariş sonrası bakiye':'Balance after the order','Bakiyeniz bu sipariş için yetersiz.':'Your balance is not enough for this order.','Bakiyeniz bu sipariş için yetersiz. Lütfen önce bakiye yükleyin.':'Your balance is not enough for this order. Please top up first.',
'Notunuz':'Your note','Siparişi onaylayın':'Confirm your order','Onayla ve öde':'Confirm and pay','Tutar bakiyenizden hemen düşülür.':'The amount is taken from your balance straight away.',
'Ekibimiz siparişinizi işleme alır. Başlamadan önce iptal ederseniz tutar bakiyenize iade edilir.':'Our team will process your order. If you cancel before they start, the amount is refunded to your balance.',
'Bazı fiyatlar az önce güncellendi. Sayfadaki yeni fiyatları kontrol edip tekrar onaylayın.':'Some prices have just changed. Please check the new prices on the page and confirm again.',
'Seçtiğiniz hizmetlerden biri artık sunulmuyor. Sayfayı yenileyip tekrar deneyin.':'One of the services you picked is no longer offered. Refresh the page and try again.','Sipariş verilemedi. Lütfen tekrar deneyin.':'Could not place the order. Please try again.',
'Hizmet siparişlerim':'My service orders','Siparişlerde ara…':'Search orders…','Henüz hizmet siparişiniz yok. Yukarıdan hizmet seçerek başlayabilirsiniz.':'No service orders yet. Pick a service above to start.',
'Hizmet siparişi':'Service order','Siparişi iptal et':'Cancel order','Bekleyen bir siparişi iptal ederseniz tutarın tamamı bakiyenize iade edilir.':'If you cancel an order that is still waiting, the full amount is refunded to your balance.',
'Bu sipariş işleme alındığı için artık iptal edilemiyor.':'This order is already being processed and can no longer be cancelled.','İptal edilemedi.':'Could not cancel.','İptal edilemedi. Lütfen tekrar deneyin.':'Could not cancel. Please try again.',
'Hizmet siparişiniz tamamlandı':'Your service order is complete','Hizmet siparişiniz iptal edildi':'Your service order was cancelled','Hesabınıza hizmet bedeli işlendi':'A service charge was added to your account',
'Siparişi tamamla':'Complete order','Kontrol et':'Check','İptal':'Cancel','Ödemeye geç':'Go to payment','kontrol ediliyor':'being checked','Kontrol ediliyor':'Being checked',
/* price list, units, database wording */
'Hizmetlerimizin güncel fiyatları. Kargo ücretleri gönderi sırasında ayrıca bildirilir.':'Our current service prices. Courier charges are given separately with each shipment.',
'Fiyat listesi henüz yayınlanmadı. Güncel fiyatlar için destek talebi oluşturabilirsiniz.':'The price list has not been published yet. Open a support ticket for current prices.','Fiyat listesi':'Price list','fiyat':'price',
'İade Yönetimi':'Returns Management','Stoklama':'Storage','yıllık':'per year','aylık':'per month','palet/ay':'pallet/month','koli/ay':'box/month',
'Koli hazırlık':'Box preparation','FNSKU etiketleme':'FNSKU labelling','Poly bag':'Poly bag','Parcel forwarding - hazır koliyi taşıyıcıya teslim etme':'Parcel forwarding - handing a ready box to the carrier',
'Return - iade adresi temini':'Return - providing a returns address','Ürünün incelenmesi - teslim alınması':'Inspecting and receiving the product','Ürünün Amazon\'a iadesi':'Returning the product to Amazon',
'Ürünün Amazon’a iadesi':'Returning the product to Amazon','Sipariş hazırlık':'Order preparation','Karton kutu - Parcel Box (small parcel)':'Cardboard box - Parcel Box (small parcel)',
'Karton kutu - Parcel Box (big parcel)':'Cardboard box - Parcel Box (big parcel)','Sipariş gönderimi - max 2 kg Royal Mail 48 saat':'Order shipping - max 2 kg Royal Mail 48 hours',
'Sipariş gönderimi - max 2 kg Royal Mail 24 saat':'Order shipping - max 2 kg Royal Mail 24 hours','Sipariş gönderimi - max 25 kg FedEx 24 saat':'Order shipping - max 25 kg FedEx 24 hours',
'Ürünün müşteriden iade alınması - max 25 kg':'Collecting a return from the customer - max 25 kg','Ürünün müşteriden iade alınması - max 2 kg':'Collecting a return from the customer - max 2 kg',
'Palet stoklama':'Pallet storage','Koli stoklama':'Box storage','Kart ödemesi':'Card payment','TEST — gerçek ödeme değil':'TEST — not a real payment',
/* balance */
'Bakiyeniz':'Your balance','muhasebe':'accounts','Tüm yükleme ve harcama kayıtlarınız.':'Everything you have paid in and spent.','güncel bakiye':'current balance','bugünkü harcama':'spent today',
'bu ayki harcama':'spent this month','toplam yüklenen':'total paid in','toplam harcanan':'total spent','şirket adı':'company name','hesap para birimi':'account currency','GBP (£)':'GBP (£)',
'Havale ile bakiye yükle':'Top up by bank transfer','Aşağıdaki hesaba havale yapın, sonra ödemenizi bildirin.':'Send a transfer to the account below, then tell us about your payment.',
'Açıklama kısmına şirket adınızı yazın, böylece ödemenizi hızlıca eşleştirebiliriz.':'Put your company name in the reference so we can match your payment quickly.',
'Kartla bakiye yükle':'Top up by card','Yüklenecek tutar (£)':'Amount to top up (£)','Tutar £50 ile £5.000 arasında olmalıdır.':'The amount must be between £50 and £5,000.',
'En az yükleme tutarı £50. Ödediğiniz tutarın tamamı bakiyenize eklenir.':'Minimum top-up £50. The full amount you pay is added to your balance.',
'Ödemeler Stripe ile güvenle alınır. Kart bilgileriniz bize ulaşmaz.':'Payments are taken securely by Stripe. Your card details never reach us.','Ödeme sayfası hazırlanıyor…':'Preparing the payment page…',
'Ödeme başlatılamadı. Lütfen biraz sonra tekrar deneyin.':'Could not start the payment. Please try again shortly.','Ödemeniz alındı. Bakiyeniz güncelleniyor…':'Payment received. Updating your balance…',
'Ödemeniz alındı. Bakiyeniz birkaç dakika içinde güncellenecek.':'Payment received. Your balance will update within a few minutes.','Ödeme alınıyor…':'Taking payment…','Teşekkürler!':'Thank you!',
'Hesap hareketleri':'Account statement','Hareketlerde ara…':'Search transactions…','Henüz hesap hareketi yok.':'No transactions yet.','Hesap hareketleri yüklenemedi.':'Could not load transactions.',
'Son 200 hareket gösterilir. Tamamı için “Excel indir” düğmesini kullanın.':'The last 200 transactions are shown. Use “Download Excel” for all of them.',
'Tüm işlemler':'All transactions','Bakiye yükleme':'Top-up','Hizmet bedeli':'Service charge','hizmet bedeli':'service charge','Düzeltme':'Adjustment','Banka havalesi':'Bank transfer',
'Bakiye (£)':'Balance (£)','Tutar (£)':'Amount (£)','tarih':'date','açıklama':'description','Banka bilgileri henüz eklenmedi.':'Bank details have not been added yet.',
'Banka bilgilerimiz yakında burada olacak.':'Our bank details will be here soon.','Banka bilgilerimiz yakında burada olacak. Bu sırada info@ecomflex.co.uk adresine yazabilirsiniz.':'Our bank details will be here soon. In the meantime you can email info@ecomflex.co.uk.',
'Banka bilgilerimiz için info@ecomflex.co.uk adresine yazın.':'Email info@ecomflex.co.uk for our bank details.','Hesap bilgileri kopyalandı':'Account details copied','Bakiye yükleyin':'Top up your balance',
'Talep oluşturabilmek için önce hesabınıza bakiye yüklemeniz gerekiyor.':'You need to top up your account before you can create requests.','Kullanılabilir':'Available','hesap':'account',
/* payment notices */
'Banka havalesiyle yaptığınız ödemeleri buradan bildirin. Ödeme hesabımıza ulaştığında onaylanır ve bakiyenize eklenir.':'Tell us here about payments you make by bank transfer. When the payment reaches our account it is confirmed and added to your balance.',
'Ödeme bildirimi oluştur':'Create payment notice','Bildirimlerde ara…':'Search notices…','Bildirimler yüklenemedi.':'Could not load notices.','Henüz ödeme bildirimi yok.':'No payment notices yet.',
'ödeme yöntemi':'payment method','ödeme tarihi':'payment date','referans':'reference','onaylandı':'confirmed','Onaylandı':'Confirmed','reddedildi':'rejected','Reddedildi':'Rejected',
'Bildirimi iptal et':'Cancel notice','Bildirim iptal edildi.':'Notice cancelled.','Yaptığınız havaleyi bildirin; hesabımıza ulaştığında onaylayıp bakiyenize ekleriz.':'Tell us about your transfer; when it reaches our account we confirm it and add it to your balance.',
'Banka hesap bilgilerimiz':'Our bank account details','Gönderilen tutar (£)':'Amount sent (£)','Lütfen gönderdiğiniz tutarı yazın.':'Please enter the amount you sent.',
'Açıklama / referans (isteğe bağlı)':'Reference (optional)','Havale açıklamasına yazdığınız metin; ödemenizi eşleştirmemize yardımcı olur.':'The text you wrote as the transfer reference; it helps us match your payment.',
'Örn. Wise 22 Eylül':'E.g. Wise 22 September','Kontrol edilmeyi bekleyen çok sayıda bildiriminiz var. Lütfen onaylanmalarını bekleyin.':'You have many notices waiting to be checked. Please wait for them to be confirmed.',
'Bildiriminiz alındı. Ödeme hesabımıza ulaştığında bakiyeniz güncellenecek.':'Notice received. Your balance will be updated when the payment reaches our account.','Ödeme yöntemleri':'Payment methods',
'Havale için banka hesap bilgilerimiz':'Our bank details for transfers','Havaleyi yaptıktan sonra “Ödeme bildirimi oluştur” ile bize bildirin. Kartla ödeme için Bakiye sayfasını kullanın.':'After making the transfer, tell us with “Create payment notice”. To pay by card, use the Balance page.',
'Ödeme bildirimi':'Payment notice','Kontrol edilen ödeme':'Payment being checked','Ödemeniz onaylandı':'Your payment was confirmed','Ödeme bildiriminiz reddedildi':'Your payment notice was rejected',
'Bildirimi gönder':'Send notice','Yeni bildirim':'New notice','Muhasebe / ödeme':'Accounts / payment',
/* invoices, monthly summary, documents, address */
'Şirketiniz için yüklediğimiz faturaları görüntüleyin ve indirin.':'View and download the invoices we have uploaded for your company.','Faturalarda ara…':'Search invoices…','Faturalar yüklenemedi.':'Could not load invoices.',
'Henüz fatura yüklenmedi.':'No invoices uploaded yet.','Yeni fatura':'New invoice','dönem':'period','dosya':'file','başlık':'title','Ay':'Month',
'Seçtiğiniz aydaki gönderi, depo ve hizmet hareketleriniz.':'Your shipments, warehouse and service activity in the month you choose.','Özeti kopyala':'Copy summary','Aylık özet kopyalandı':'Monthly summary copied',
'Gönderilen sipariş':'Orders sent','Kargo':'Courier','Hizmet':'Service','İade / kargo':'Returns / courier','Açılış':'Opening','Kapanış':'Closing',
'Sözleşmeler, ödeme yöntemleri ve paylaştığımız diğer belgeler.':'Contracts, payment methods and other documents we share with you.','Belgeler yüklenemedi.':'Could not load documents.','Henüz paylaşılan belge yok.':'No documents shared yet.',
'Ürünlerinizi ve iadelerinizi bu adrese gönderin. Birim numaranızı yazmayı unutmayın.':'Send your products and returns to this address. Do not forget your unit number.','Depo adresim':'My warehouse address',
'Depo birim numaranız henüz atanmadı. Atandığında adresiniz burada görünecek.':'Your warehouse unit number has not been assigned yet. Your address will appear here once it is.',
'Depo birim numaranız henüz atanmadı. Atandığında adresiniz burada görünecek. Sorunuz varsa destek talebi oluşturun.':'Your warehouse unit number has not been assigned yet. Your address will appear here once it is. If you have questions, open a support ticket.',
'Tedarikçileriniz ve iadeler için.':'For your suppliers and returns.','depo':'warehouse',
/* support */
'Sorularınızı ekibimize yazın; yanıtlarımızı burada görün.':'Write your questions to our team and see our replies here.','Yeni talep':'New ticket','Yeni destek talebi':'New support ticket','Konu':'Subject','Mesajınız':'Your message',
'Lütfen bir konu yazın.':'Please enter a subject.','Lütfen mesajınızı yazın.':'Please write your message.','Destek talebiniz alındı.':'Support ticket received.','Ekibimiz en kısa sürede yanıtlar.':'Our team will reply as soon as possible.',
'Henüz destek talebiniz yok. Sorunuz için “Yeni talep” oluşturun.':'You have no support tickets yet. Create a “New ticket” for your question.','Açık':'Open','açık':'open','Yanıtlandı':'Answered','yanıtlandı':'answered',
'Kapandı':'Closed','kapandı':'closed','Talebi kapat':'Close ticket','Talep kapatıldı.':'Ticket closed.','Kapatılamadı.':'Could not close.','Yanıtınızı yazın…':'Write your reply…','yanıt yaz':'write a reply',
'Yazarsanız talep yeniden açılır.':'If you write, the ticket reopens.','ecomFLEX yanıtı':'ecomFLEX reply','ecomFLEX Destek':'ecomFLEX Support','Destek talebinize yanıt geldi':'Your support ticket has a reply',
'Çok sayıda açık talebiniz var. Lütfen önce mevcut taleplerinizin yanıtlanmasını bekleyin.':'You have many open tickets. Please wait for replies to your current tickets first.','Destek talepleri':'Support tickets',
'Muhasebe / ödeme':'Accounts / payment','Gönderi / kargo':'Shipment / courier','Stok / depo':'Stock / warehouse','yeni yanıt':'new reply','Mesajınız gönderildi.':'Message sent.',
/* chat */
'Ekibimizle doğrudan yazışın. Mesajınız okunduğunda iki mavi tik görünür.':'Chat directly with our team. Two blue ticks appear when your message has been read.','ecomFLEX ekibi':'ecomFLEX team','Bir mesaj yazın':'Type a message',
'Henüz mesaj yok. Sorularınızı buraya yazın; ekibimiz buradan yanıtlar. Gönderi, stok veya ödeme ile ilgili her konuda yazabilirsiniz.':'No messages yet. Write your questions here and our team will reply here. You can write about shipments, stock, payments or anything else.',
'Mesajlar yüklenemedi.':'Could not load messages.','Çok hızlı mesaj gönderiyorsunuz. Lütfen biraz bekleyin.':'You are sending messages too quickly. Please wait a moment.','Enter':'Enter','Escape':'Escape','Yardım:':'Help:',
/* notifications */
'Son 30 günde bildirim yok.':'No notifications in the last 30 days.','son 30 gün':'last 30 days','Tümünü gör':'See all','destek':'support',
/* account menu */
'Giriş kodunuz kopyalandı':'Sign-in code copied','Kod kopyalandı':'Code copied',
/* signup */
'Yeni müşteri kaydı':'New customer sign-up','Yeni Müşteri Kaydı — ecomFLEX':'New Customer Sign-up — ecomFLEX','yeni müşteri':'new customer','Zaten müşterimiz misiniz?':'Already a customer?',
'ecomFLEX’e gösterdiğiniz ilgi için çok teşekkür ederiz. Size daha iyi hizmet verebilmemiz için lütfen aşağıdaki bilgileri doldurun. İyi günler dileriz.':'Thank you very much for your interest in ecomFLEX. To help us serve you better, please fill in the details below. Have a nice day.',
'HMRC onaylı fulfilment merkezi':'HMRC-approved fulfilment centre','Hesabınız anında açılır':'Your account opens instantly','Yaklaşık 3 dakika':'About 3 minutes',
'İletişim bilgileriniz':'Your contact details','Panel hesabınız bu bilgilerle oluşturulur.':'Your panel account is created with these details.','E-posta':'Email','Telefon numaranız':'Your phone number',
'Adınız soyadınız':'Your full name','Şirket adresiniz':'Your company address','Lütfen geçerli bir e-posta adresi yazın.':'Please enter a valid email address.','Lütfen geçerli bir telefon numarası yazın.':'Please enter a valid phone number.',
'Lütfen ad ve soyadınızı yazın.':'Please enter your full name.','Lütfen şirket adınızı yazın.':'Please enter your company name.','Lütfen şirket adresinizi yazın.':'Please enter your company address.',
'Çalışma yönteminiz':'How you work','Birden fazla seçebilirsiniz.':'You can choose more than one.','Diğer (yazabilirsiniz)':'Other (you can type)','Lütfen en az bir seçenek işaretleyin.':'Please tick at least one option.',
'İlgilendiğiniz hizmetlerimiz':'Services you are interested in','Talebiniz ile ilgili detaylı bilgi':'Details about what you need',
'Aylık yaklaşık kaç koli, hangi pazaryerleri ve varsa özel istekleriniz.':'Roughly how many boxes a month, which marketplaces, and any special requests.','Aylık kaç koli, hangi pazaryerleri, özel isteğiniz…':'Boxes per month, marketplaces, special requests…',
'Lütfen kısaca yazın.':'Please write a few words.','ecomFLEX’i nereden duydunuz?':'How did you hear about ecomFLEX?','Hesabınız anında oluşturulur.':'Your account is created instantly.',
'Size özel 8 haneli bir giriş kodu verilir; panele bu kodla girersiniz.':'You get your own 8-character sign-in code; you use it to enter the panel.','Kaydı tamamla':'Complete sign-up','Hesabınız oluşturuluyor…':'Creating your account…',
'Kaydınız tamamlandı':'Sign-up complete','Panele girmek için kullanacağınız kod:':'The code you will use to enter the panel:','Bu kodu saklayın.':'Keep this code safe.',
'Panele girmek için tek ihtiyacınız olan şey budur. Kimseyle paylaşmayın — kodu bilen herkes hesabınıza girebilir. Kodunuzu kaybederseniz':'It is all you need to enter the panel. Do not share it — anyone with the code can enter your account. If you lose your code, write to us at',
'adresinden bize yazın.':'.','Kodu kopyala':'Copy code','Panele git':'Go to the panel','Kod kopyalandı':'Code copied',
'Sıradaki adım: panele girip hesabınıza ilk yüklemenizi yapın. İlk yükleme yapılana kadar talep oluşturamazsınız.':'Next step: enter the panel and make your first top-up. You cannot create requests until the first top-up has arrived.',
'Bu e-posta ile zaten bir kayıt var. Panele giriş yapın veya kodunuz için':'There is already an account with this email. Sign in to the panel, or for your code email','Diğer çalışma yöntemi':'Other way of working','Diğer hizmet':'Other service',
'Üretici':'Manufacturer','Toptancı':'Wholesaler','Private Label':'Private Label','Retail - Online Arbitraj':'Retail - Online Arbitrage','FBA':'FBA','FBM':'FBM','Dropshipping':'Dropshipping',
'Fulfilment, depolama':'Fulfilment, storage','Pazaryerleri hesap açılışı, ürün listelenmesi':'Marketplace account opening, product listing','Pazaryeri hesap yönetimi':'Marketplace account management',
'Pazar, rekabet ve maliyet analizi':'Market, competition and cost analysis','Şirket kuruluşu, banka hesabı açılması':'Company formation, bank account opening','İade - Şirket adresi hizmeti':'Returns - company address service',
'Arama motoru':'Search engine','Web sitesi':'Website','Instagram':'Instagram','LinkedIn':'LinkedIn','WhatsApp grupları':'WhatsApp groups','Arkadaş tavsiyesi':'Recommended by a friend',
'Kodu elle not alın:':'Write the code down:','Kayıt tamamlanamadı. Lütfen tekrar deneyin.':'Could not complete sign-up. Please try again.',
/* months */
'Ocak':'January','Şubat':'February','Mart':'March','Nisan':'April','Mayıs':'May','Haziran':'June','Temmuz':'July','Ağustos':'August','Eylül':'September','Ekim':'October','Kasım':'November','Aralık':'December',
'Oca':'Jan','Şub':'Feb','Mar':'Mar','Nis':'Apr','May':'May','Haz':'Jun','Tem':'Jul','Ağu':'Aug','Eyl':'Sep','Eki':'Oct','Kas':'Nov','Ara':'Dec',
'Ekibimize soru sorun':'Ask our team','İşlem bekliyor':'Waiting',
/* added after the full check */
'Gönderileriniz, gelen kargolarınız ve talepleriniz.':'Your shipments, deliveries and requests.','sku / ürün kodu':'sku / product code','sku / kod':'sku / code','ürün / sku':'product / sku',
'Dikkat edilmesi gerekenler':'Things to note','sayfasından bildirin; teslim alındığında sayılıp stoğunuza eklenir.':'page; when it arrives it is counted and added to your stock.',
'İlçe/Bölge (County/Region) alanı zorunluysa':'If a County/Region field is required, write','yazın.':'.','sayfasını kullanın.':'page.',
', ardından siparişinizi tamamlayın.':', then complete your order.','Ürün adı veya SKU':'Product name or SKU','güncellenecek':'will be updated','Oluşturma':'Created','oluşturma':'created',
'Servis':'Service','Depomuzdaki ürününüzü müşterinize gönderelim.':'We send your product from our warehouse to your customer.','Belirtilmedi':'Not given',
'Değiştir':'Replace','Etiket yükle':'Upload label','Etiket yüklendi.':'Label uploaded.','Etiket yüklenemedi. Lütfen tekrar deneyin.':'Could not upload the label. Please try again.',
'Koli':'Box','etiket var':'label added','etiket yok':'no label','Koli ölçülerini kopyala':'Copy box dimensions','Koli ölçüleri kopyalandı':'Box dimensions copied',
'Yeni FNSKU etiketi ekle (PDF)':'Add new FNSKU label (PDF)','+ Satır ekle':'+ Add line','En az bir satır doldurun (FNSKU ve adet).':'Fill in at least one line (FNSKU and quantity).',
'FBA hazırlık talebi':'FBA prep request','Amazon deposuna gönderilecek ürünleri bildirin. Size özel bir talep numarası verilir.':'Tell us which products are going to the Amazon warehouse. You get your own request number.',
'ürünün üzerindeki fnsku / asin':'fnsku / asin on the product','yapıştırılacak yeni fnsku':'new fnsku to stick on','Amazon Shipment ID (isteğe bağlı)':'Amazon Shipment ID (optional)',
'Hedef Amazon deposu (isteğe bağlı)':'Destination Amazon warehouse (optional)','En az bir satır ekleyin.':'Add at least one line.','Dosyalar yükleniyor…':'Uploading files…',
'Sipariş iptal edildi.':'Order cancelled.','Sipariş numarası, SKU veya takip numarası varsa ekleyin.':'Add an order number, SKU or tracking number if you have one.'
};

/* ---------- phrases with numbers, amounts or names inside ---------- */
var MON={'Ocak':'January','Şubat':'February','Mart':'March','Nisan':'April','Mayıs':'May','Haziran':'June','Temmuz':'July','Ağustos':'August','Eylül':'September','Ekim':'October','Kasım':'November','Aralık':'December'};
var P=[
  [/^(.+) — ecomFLEX$/, function(m,a){ return T(a)+' — ecomFLEX'; }],
  [/^Kod: (.+)$/, 'Code: $1'],
  [/^(\d+) duyuru$/, '$1 announcements'],
  [/^Giriş kodumu kopyala \((.+)\)$/, 'Copy my sign-in code ($1)'],
  [/^\+(.+) bu ay giriş$/, '+$1 in this month'],
  [/^(.+) üründe stok var$/, '$1 products in stock'],
  [/^(.+) bu ay net$/, '$1 net this month'],
  [/^([+-]?\d+),(\d+)%$/, '$1.$2%'],
  [/^(\d+) azalan$/, '$1 running low'],
  [/^(\d+) hazırlanıyor$/, '$1 being prepared'],
  [/^(\d+) bekleniyor$/, '$1 expected'],
  [/^(\d+) etiket bekleniyor$/, '$1 waiting for labels'],
  [/^(\d+) açık$/, '$1 open'],
  [/^(\d+) kontrolde$/, '$1 being checked'],
  [/^(\d+) yeni yanıt$/, '$1 new replies'],
  [/^(\d+) yeni$/, '$1 new'],
  [/^([\d.,]+) ürün$/, '$1 products'],
  [/^([\d.,]+) adet$/, '$1 units'],
  [/^([\d.,]+) adet bildirildi$/, '$1 units declared'],
  [/^(\?|\d+) koli$/, '$1 boxes'],
  [/^(\d+) hizmet$/, '$1 services'],
  [/^(.*) \+(\d+) kalem$/, '$1 +$2 more'],
  [/^Talep (.*) · her koli için etiket yükleyin$/, 'Request $1 · upload a label for each box'],
  [/^Tümünü gör \((\d+)\)$/, 'See all ($1)'],
  [/^Teşekkürler! (.+) bakiyenize eklendi\.$/, 'Thank you! $1 has been added to your balance.'],
  [/^(.+) bakiyenize eklendi\.?$/, '$1 added to your balance'],
  [/^(.+) bakiyenize iade edildi\.?$/, '$1 refunded to your balance'],
  [/^(.+) bakiyenize iade edilir\.$/, '$1 will be refunded to your balance.'],
  [/^Koli (\d+)$/, 'Box $1'],
  [/^(Ocak|Şubat|Mart|Nisan|Mayıs|Haziran|Temmuz|Ağustos|Eylül|Ekim|Kasım|Aralık) (\d{4})$/, function(m,mo,y){ return MON[mo]+' '+y; }],
  [/^Kaydedilemedi\.\s*(.*)$/, 'Could not save. $1'],
  [/^Yüklenemedi\.\s*(.*)$/, 'Could not upload. $1'],
  [/^Gönderilemedi[.:]\s*(.*)$/, 'Could not send. $1'],
  [/^(\d+) alıcı kaydedildi\.$/, '$1 recipients saved.'],
  [/^(.+) zaten ürün listenizde\. Bilgilerini güncellemek istiyor musunuz\?$/, '$1 is already in your product list. Do you want to update its details?'],
  [/^(\d+) ürün hazır, (\d+) satır atlanacak$/, '$1 products ready, $2 rows will be skipped'],
  [/^(\d+) ürün hazır$/, '$1 products ready'],
  [/^(\d+) ürünü yükle$/, 'Upload $1 products'],
  [/^(.+) ürün kaydedildi\.$/, '$1 products saved.'],
  [/^(.+) alıcı listenizden silinsin mi\?$/, 'Remove $1 from your recipients?'],
  [/^Son 12 aydaki gönderilerinizden (\d+) yeni alıcı bulundu\. Kaydedilsin mi\?$/, 'Found $1 new recipients in your shipments from the last 12 months. Save them?'],
  [/^(.*)\(stok: (-?\d+)\)$/, '$1(stock: $2)'],
  [/^Depoda (\d+) adet var\.$/, '$1 units in the warehouse.'],
  [/^Depoda yalnızca (\d+) adet var\. Yine de (\d+) adet talep etmek istiyor musunuz\?$/, 'Only $1 units are in the warehouse. Do you still want to request $2?'],
  [/^stok yetersiz \((-?\d+)\)$/, 'not enough stock ($1)'],
  [/^(\d+) satır hazır, (\d+) satırda sorun var$/, '$1 rows ready, $2 rows have a problem'],
  [/^(\d+) satır hazır$/, '$1 rows ready'],
  [/^(\d+) gönderiyi oluştur$/, 'Create $1 shipments'],
  [/^(\d+) gönderi oluşturulacak\. Devam edilsin mi\?$/, '$1 shipments will be created. Continue?'],
  [/^(\d+) gönderi talebi oluşturuldu\.$/, '$1 shipment requests created.'],
  [/^FBA talebiniz alındı\. Talep numaranız: (.+)$/, 'FBA request received. Your request number: $1'],
  [/^birim: (.+)$/, function(m,a){ return 'unit: '+T(a); }],
  [/^(.+) adet$/, function(m,a){ return 'Quantity: '+T(a); }],
  [/^Bakiyeden öde · (.+)$/, 'Pay from balance · $1'],
  [/^(.+) bakiyenizden düşülecek\. Sipariş sonrası bakiye: (.+)$/, '$1 will be taken from your balance. Balance after the order: $2'],
  [/^Siparişiniz alındı \(#(\d+)\)\. (.+) bakiyenizden düşüldü\.$/, 'Order received (#$1). $2 has been taken from your balance.'],
  [/^Sipariş iptal edildi\. (.+) bakiyenize iade edildi\.$/, 'Order cancelled. $1 has been refunded to your balance.'],
  [/^Hizmet siparişi #(\d+)(.*)$/, 'Service order #$1$2'],
  [/^İade: hizmet siparişi #(\d+)(.*)$/, 'Refund: service order #$1$2'],
  [/^Hizmet bedeli #(\d+)(.*)$/, 'Service charge #$1$2'],
  [/^Havale( — (.*))?$/, function(m,a,b){ return 'Bank transfer'+(b?' — '+b:''); }],
  [/^(.+) tutarındaki ödemeniz için teşekkürler\. Bundan sonrası bizde:$/, 'Thank you for your payment of $1. We take it from here:'],
  [/^(.+) tutarındaki bildirim iptal edilsin mi\?$/, 'Cancel the payment notice for $1?'],
  [/^(.+) tutarındaki ödeme bildiriminiz bize ulaştı\. Para hesabımıza geçtiğinde kontrol edip bakiyenize ekleyeceğiz\. Eklendiğinde zil simgesinde bildirim görürsünüz ve hesabınız açılır\.$/,
    'Your payment notice for $1 has reached us. When the money arrives in our account we will check it and add it to your balance. You will then see a notification under the bell and your account will open.'],
  [/^(.+) numaralı sipariş iptal edilsin mi\?$/, 'Cancel order $1?'],
  [/^(.+) numaralı talep kapatılsın mı\?$/, 'Close ticket $1?'],
  [/^(.+) — ecomFLEX aylık özet$/, '$1 — ecomFLEX monthly summary'],
  [/^(\d{1,2}) (Ocak|Şubat|Mart|Nisan|Mayıs|Haziran|Temmuz|Ağustos|Eylül|Ekim|Kasım|Aralık)( \d{4})?$/, function(m,d,mo,y){ return d+' '+MON[mo]+(y||''); }],
  [/^(.+) tamamlandı$/, function(m,a){ return T(a)+' completed'; }],
  [/^Kayıt tamamlanamadı\. Lütfen tekrar deneyin\.\s*(.*)$/, 'Could not complete sign-up. Please try again. $1'],
  [/^Kodu elle not alın: (.+)$/, 'Write the code down: $1']
];

/* ---------- translating one piece of text ---------- */
var TRCH=/[çğıöşüÇĞİÖŞÜ]/;
var HAS=Object.prototype.hasOwnProperty;
function norm(s){ return String(s).replace(/\s+/g,' ').trim(); }
function t(s,depth){
  var n=norm(s); if(!n) return null;
  if(HAS.call(D,n)) return D[n];
  for(var i=0;i<P.length;i++){
    var m=n.match(P[i][0]);
    if(m){ var r=P[i][1]; return typeof r==='function'? r.apply(null,m) : n.replace(P[i][0],r); }
  }
  /* "a · b" or "a, b": translate the parts when every Turkish part is known */
  if((depth||0)<2){
    var seps=[' · ',', '];
    for(var j=0;j<seps.length;j++){
      if(n.indexOf(seps[j])<0) continue;
      var any=false, all=true;
      var out=n.split(seps[j]).map(function(p){ var x=t(p,(depth||0)+1); if(x!==null){ any=true; return x; } if(TRCH.test(p)) all=false; return p; });
      if(any&&all) return out.join(seps[j]);
    }
  }
  return null;
}
function T(s){ var x=t(s); return x===null? s : x; }

/* ---------- applying it to the page ---------- */
var DONE=new WeakMap(), ADONE=new WeakMap();
var ATTRS=['placeholder','title','aria-label'];
function blocked(el){ return !el||!el.closest||el.closest('[data-noi18n],script,style,textarea'); }
function doText(n){
  if(lang!=='en') return;
  var v=n.nodeValue; if(!v||!/[A-Za-zÇĞİÖŞÜçğıöşü]/.test(v)) return;
  var rec=DONE.get(n); if(rec&&rec.e===v) return;
  if(blocked(n.parentNode)) return;
  var e=t(v); if(e===null) return;
  var nv=v.match(/^\s*/)[0]+e+v.match(/\s*$/)[0];
  if(nv===v) return;
  DONE.set(n,{o:v,e:nv}); n.nodeValue=nv;
}
function doAttr(el,a){
  if(lang!=='en'||!el.getAttribute) return;
  var v=el.getAttribute(a); if(!v) return;
  var recs=ADONE.get(el)||{}; if(recs[a]&&recs[a].e===v) return;
  if(blocked(el)&&el.closest&&el.closest('[data-noi18n]')) return;
  var e=t(v); if(e===null||e===v) return;
  recs[a]={o:v,e:e}; ADONE.set(el,recs); el.setAttribute(a,e);
}
function walk(root){
  if(!root) return;
  if(root.nodeType===3){ doText(root); return; }
  if(root.nodeType!==1&&root.nodeType!==9) return;
  if(root.nodeType===1) ATTRS.forEach(function(a){ if(root.hasAttribute(a)) doAttr(root,a); });
  var w=document.createTreeWalker(root,5,null), n;  /* elements + text */
  while((n=w.nextNode())){
    if(n.nodeType===3) doText(n);
    else for(var i=0;i<ATTRS.length;i++) if(n.hasAttribute(ATTRS[i])) doAttr(n,ATTRS[i]);
  }
}
function revert(){
  var w=document.createTreeWalker(document.documentElement,5,null), n;
  while((n=w.nextNode())){
    if(n.nodeType===3){ var r=DONE.get(n); if(r&&n.nodeValue===r.e) n.nodeValue=r.o; DONE.delete(n); }
    else { var rs=ADONE.get(n); if(rs){ for(var a in rs) if(HAS.call(rs,a)&&n.getAttribute(a)===rs[a].e) n.setAttribute(a,rs[a].o); ADONE.delete(n); } }
  }
}
var mo=new MutationObserver(function(list){
  if(lang!=='en') return;
  for(var i=0;i<list.length;i++){
    var r=list[i];
    if(r.type==='childList') for(var k=0;k<r.addedNodes.length;k++) walk(r.addedNodes[k]);
    else if(r.type==='characterData') doText(r.target);
    else if(r.type==='attributes') doAttr(r.target,r.attributeName);
  }
});
mo.observe(document.documentElement,{childList:true,subtree:true,characterData:true,attributes:true,attributeFilter:ATTRS});

/* pop-up questions */
['alert','confirm','prompt'].forEach(function(k){
  var orig=window[k]; if(!orig) return;
  window[k]=function(msg){
    var a=Array.prototype.slice.call(arguments);
    if(lang==='en'&&typeof msg==='string') a[0]=msg.split('\n').map(function(l){ return l.trim()? T(l) : l; }).join('\n');
    return orig.apply(window,a);
  };
});

/* ---------- the TR / EN switch ---------- */
var css=document.createElement('style');
css.textContent='.langsw{display:inline-flex;align-items:center;gap:2px;height:38px;padding:3px;border:1px solid #E7E8EE;border-radius:999px;background:#fff;flex:none}'
 +'.langsw button{border:0;background:none;height:30px;min-width:36px;padding:0 9px;border-radius:999px;font:600 .74rem/1 Inter,system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;'
 +'letter-spacing:.04em;color:#6F7189;cursor:pointer}'
 +'.langsw button:hover{color:#23233B}.langsw button[aria-pressed="true"]{background:#23233B;color:#fff}'
 +'.langsw button:focus-visible{outline:2px solid #45B0C8;outline-offset:2px}';
document.head.appendChild(css);
function mount(el){
  if(el._lsw) return; el._lsw=true;
  el.setAttribute('data-noi18n',''); el.setAttribute('role','group'); el.setAttribute('aria-label','Dil / Language');
  ['tr','en'].forEach(function(l){
    var b=document.createElement('button'); b.type='button'; b.setAttribute('data-l',l); b.textContent=l.toUpperCase();
    b.setAttribute('title',l==='tr'?'Türkçe':'English');
    b.onclick=function(){ set(l); };
    el.appendChild(b);
  });
  paint();
}
function paint(){
  var bs=document.querySelectorAll('.langsw button');
  for(var i=0;i<bs.length;i++) bs[i].setAttribute('aria-pressed',String(bs[i].getAttribute('data-l')===lang));
}
var subs=[];
function set(l){
  l=l==='en'?'en':'tr'; if(l===lang) return;
  lang=l; try{ localStorage.setItem(KEY,l); }catch(e){}
  document.documentElement.lang=l;
  if(l==='en') walk(document.documentElement); else revert();
  paint();
  subs.forEach(function(f){ try{ f(l); }catch(e){} });
}
function mountAll(){ var els=document.querySelectorAll('[data-langsw]'); for(var i=0;i<els.length;i++) mount(els[i]); }
document.documentElement.lang=lang;
function ready(){
  mountAll();
  if(lang==='en') walk(document.documentElement);
  /* copied text that has several lines (e.g. the monthly summary) follows the language too */
  var c=window.EFCopy;
  if(c&&!c._i18n){
    window.EFCopy=function(text,label,btn){
      if(lang==='en'&&typeof text==='string'&&text.indexOf('\n')>-1&&TRCH.test(text)) text=text.split('\n').map(function(l){ return l.trim()? T(l) : l; }).join('\n');
      return c(text,label&&lang==='en'?T(label):label,btn);
    };
    window.EFCopy._i18n=true;
  }
}
if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',ready); else ready();

window.EFLang={
  get:function(){ return lang; },
  set:set,
  t:function(s){ return lang==='en'? T(s) : s; },
  known:function(s){ return t(s)!==null; },
  onchange:function(f){ subs.push(f); },
  mount:mount
};
})();
