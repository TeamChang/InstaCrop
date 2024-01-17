//
//  EditVC.swift
//  InstaCrop
//
//  Created by Timchang Wuyep on 27/12/2023.
//

import UIKit
import Photos
import GoogleMobileAds
import StoreKit
import SVProgressHUD

class EditVC: UIViewController, UIScrollViewDelegate {

    @IBOutlet weak var viewBg: UIView!
    
    @IBOutlet weak var enlargeBtn: UIButton!
    @IBOutlet weak var blurBtn: UIButton!
    @IBOutlet weak var filterBtn: UIButton!
    @IBOutlet weak var exportBtn: UIButton!
    @IBOutlet weak var imageViewBg: UIImageView!
    
    @IBOutlet weak var iconsView: UIView!
    var editImage: UIImage?
    
    var isPotrait = true
    var isBlur = true
    var isFilterEnable = false
    
    var filterImageView = UIImageView()
    var filterImageNames = [String]()
    var customView: UIView?
    
    
    var interstitialAdCount = 0
    
    let extensions = Extensions()
    
    private var bannerView: GADBannerView! //googleAds banner
    private var interstitial: GADInterstitialAd? //googleAds interstitial
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let isPaid = UserDefaults.standard.bool(forKey: "isPaid")
        if (!isPaid) {
            
            loadBannerAd()
            loadInterstitialAd()
        }
        
        extensions.setupShadow(viewBg: viewBg)

        if let image = editImage {
            
            imageViewBg.image = extensions.applyBlur(to: image, intensity: 1.0)
        }
        
        potrait()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let isPaid = UserDefaults.standard.bool(forKey: "isPaid")
        if (isPaid) {

            bannerView?.isHidden = true
            interstitial = nil
        }
        
    }
    
    
    
    
    
    @IBAction func enlargeBtnPressed(_ sender: UIButton) {
        
        if isPotrait {
            
            enlargeBtn.setImage(UIImage(systemName: "arrow.up.and.down.circle"), for: .normal)
            
            landscape()
            
        } else {
    
            enlargeBtn.setImage(UIImage(systemName: "arrow.left.and.right.circle"), for: .normal)
            
            potrait()
        }
        
        isPotrait.toggle()
    }
    
    @IBAction func blurBtnPressed(_ sender: UIButton) {
        
        if isBlur {
            
            blurBtn.setImage(UIImage(systemName: "circle.fill"), for: .normal)
            
            imageViewBg.image = nil
            imageViewBg.backgroundColor = .white
            
        } else {
            
            if let image = editImage {
                
                blurBtn.setImage(UIImage(systemName: "circle.slash.fill"), for: .normal)
                
                imageViewBg.image = extensions.applyBlur(to: image, intensity: 1.0)
            }
        }
        
        isBlur.toggle()
    }
    
    @IBAction func filterBtnPressed(_ sender: UIButton) {
        
        if isFilterEnable {
            
            // Remove the view
            filterImageView.removeFromSuperview()
            removeFilterView()
            
        } else {
            
            addFilterView()
        }
        
        isFilterEnable.toggle()
    }
    
    @IBAction func exportBtnPressed(_ sender: UIButton) {
        
        let isPaid = UserDefaults.standard.bool(forKey: "isPaid")
        if !isPaid {
          if interstitialAdCount == 0 {
              self.displayInterstitialAd()
              interstitialAdCount += 1
          }
        }
        
        let imageToSave = viewBg?.takeScreenshot(with: 5.0) ?? UIImage()
        
        shareImageToInstagram(sender: sender, image: imageToSave)

        
//        SVProgressHUD.show()
//        extensions.saveImageToPhotosAlbum(imageToSave) { success, error in
//            if success {
//
//                SVProgressHUD.dismiss()
//                self.extensions.presentAlert(title: nil,
//                                        message: NSLocalizedString("imageSaved", comment: "imageSaved"),
//                                        imageName: nil,
//                                        viewController: self)
//
//                print("Image saved successfully.")
//            } else {
//
//                print("Failed. Something went wrong.")
//                SVProgressHUD.dismiss()
//
//                if let error = error {
//
//                    self.extensions.presentAlert(title: nil,
//                                            message: error.localizedDescription,
//                                            imageName: "icons-error",
//                                            viewController: self)
//                } else {
//
//                    self.extensions.presentAlert(title: nil,
//                                                 message: NSLocalizedString("imageNotSaved", comment: "imageNotSaved"),
//                                            imageName: "icons-error",
//                                            viewController: self)
//                }
//            }
//        }
    }
    
    // MARK: - App Review
    func review() {
        
        // If the count has not yet been stored, this will return 0
        var count = UserDefaults.standard.integer(forKey: UserDefaultsKeys.processCompletedCountKey)
        count += 1
        UserDefaults.standard.set(count, forKey: UserDefaultsKeys.processCompletedCountKey)
        
        print("Process completed \(count) time(s)")
        
        // Get the current bundle version for the app
        let infoDictionaryKey = kCFBundleVersionKey as String
        guard let currentVersion = Bundle.main.object(forInfoDictionaryKey: infoDictionaryKey) as? String
            else { fatalError("Expected to find a bundle version in the info dictionary") }
        
        let lastVersionPromptedForReview = UserDefaults.standard.string(forKey: UserDefaultsKeys.lastVersionPromptedForReviewKey)
        
        // Has the process been completed several times and the user has not already been prompted for this version?
        if count >= 4 && currentVersion != lastVersionPromptedForReview {
            let twoSecondsFromNow = DispatchTime.now() + 2.0
            DispatchQueue.main.asyncAfter(deadline: twoSecondsFromNow) { [navigationController] in
                if navigationController?.topViewController is ViewController {
                    
                    if #available(iOS 14.0, *) {
                          if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                              SKStoreReviewController.requestReview(in: scene)
                          }
                      } else {
                          SKStoreReviewController.requestReview()
                      }
                    UserDefaults.standard.set(currentVersion, forKey: UserDefaultsKeys.lastVersionPromptedForReviewKey)
                }
            }
        }
        
    }
    
    // MARK: - Functions
    
    private func potrait() {
        
        print("potrait")
        // Remove all existing subviews from imageViewBg
        imageViewBg.subviews.forEach { $0.removeFromSuperview() }
        
        // Create a new UIView to add to imageViewBg because adding second image directly doesn't work, we need to add 2nd imageView to uiview
        let bgUIView = UIView()
        bgUIView.translatesAutoresizingMaskIntoConstraints = false
        //bgUIView.backgroundColor = UIColor.green

        imageViewBg.addSubview(bgUIView)

        // Set up constraints for bgUIView within imageViewBg
        NSLayoutConstraint.activate([
            bgUIView.topAnchor.constraint(equalTo: imageViewBg.topAnchor),
            bgUIView.bottomAnchor.constraint(equalTo: imageViewBg.bottomAnchor),
            bgUIView.leadingAnchor.constraint(equalTo: imageViewBg.leadingAnchor, constant: 45),
            bgUIView.trailingAnchor.constraint(equalTo: imageViewBg.trailingAnchor, constant: -45),
        ])

        // Create a new UIImageView (imageViewFg)
        let imageViewFg = UIImageView()
        imageViewFg.translatesAutoresizingMaskIntoConstraints = false
        if let image = editImage {
            imageViewFg.image = image
            imageViewFg.contentMode = .scaleAspectFill
            imageViewFg.clipsToBounds = true
        }
        
        // Add imageViewFg to the view
        bgUIView.addSubview(imageViewFg)

        // Set up constraints for imageViewFg based on imageViewBg
        NSLayoutConstraint.activate([
            imageViewFg.topAnchor.constraint(equalTo: bgUIView.topAnchor),
            imageViewFg.bottomAnchor.constraint(equalTo: bgUIView.bottomAnchor),
            imageViewFg.leadingAnchor.constraint(equalTo: bgUIView.leadingAnchor),
            imageViewFg.trailingAnchor.constraint(equalTo: bgUIView.trailingAnchor),

        ])
    }
    
    private func landscape() {
        
        print("landscape")
        // Remove all existing subviews from imageViewBg
        imageViewBg.subviews.forEach { $0.removeFromSuperview() }

        // Create a new UIView to add to imageViewBg
        let bgUIView = UIView()
        bgUIView.translatesAutoresizingMaskIntoConstraints = false
        //bgUIView.backgroundColor = UIColor.blue

        imageViewBg.addSubview(bgUIView)

        // Set up constraints for bgUIView within imageViewBg
        NSLayoutConstraint.activate([
            bgUIView.topAnchor.constraint(equalTo: imageViewBg.topAnchor, constant: 45),
            bgUIView.bottomAnchor.constraint(equalTo: imageViewBg.bottomAnchor, constant: -45),
            bgUIView.leadingAnchor.constraint(equalTo: imageViewBg.leadingAnchor),
            bgUIView.trailingAnchor.constraint(equalTo: imageViewBg.trailingAnchor),
        ])
        
        // Create a new UIImageView (imageViewFg)
        let imageViewFg = UIImageView()
        imageViewFg.translatesAutoresizingMaskIntoConstraints = false
        //imageViewFg.backgroundColor = UIColor.red
        if let image = editImage {
            imageViewFg.image = image
            imageViewFg.contentMode = .scaleAspectFit
            imageViewFg.clipsToBounds = true
        }

        // Add imageViewFg to the view
        bgUIView.addSubview(imageViewFg)

        // Set up constraints for imageViewFg based on imageViewBg
        NSLayoutConstraint.activate([
            imageViewFg.topAnchor.constraint(equalTo: bgUIView.topAnchor),
            imageViewFg.bottomAnchor.constraint(equalTo: bgUIView.bottomAnchor),
            imageViewFg.leadingAnchor.constraint(equalTo: bgUIView.leadingAnchor),
            imageViewFg.trailingAnchor.constraint(equalTo: bgUIView.trailingAnchor),
        ])
    }
    
    private func removeFilterView() {
        
        customView?.removeFromSuperview()
        customView = nil
    }
    
    private func addFilterView() {
        
        // Add the view
        customView = UIView()
        customView?.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(customView!)
        
        // Add height, leading, trailing, and bottom constraints
        customView?.heightAnchor.constraint(equalToConstant: 60).isActive = true
        customView?.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8).isActive = true
        customView?.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8).isActive = true
        customView?.bottomAnchor.constraint(equalTo: iconsView.topAnchor, constant: -3).isActive = true
        
        // Create and configure the UICollectionView
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal // or .vertical, depending on your design

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.showsHorizontalScrollIndicator = false

        // Register collection view cells
        collectionView.register(UINib(nibName: "FiltersCell", bundle: nil), forCellWithReuseIdentifier: "filtersCell")
        
        filterImageNames = ["None","Posterize","Process","Invert","SepiaTone","Chrome","Fade","Instant","Noir","Tonal"]

        // Add the collection view to the custom view
        customView?.addSubview(collectionView)

        // Add constraints for the collection view
        collectionView.topAnchor.constraint(equalTo: customView!.topAnchor).isActive = true
        collectionView.leadingAnchor.constraint(equalTo: customView!.leadingAnchor).isActive = true
        collectionView.trailingAnchor.constraint(equalTo: customView!.trailingAnchor).isActive = true
        collectionView.bottomAnchor.constraint(equalTo: customView!.bottomAnchor).isActive = true
    }
    
    func shareImageToInstagram(sender: UIButton, image: UIImage) {
        
        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            // Unable to convert the image to data
            
            self.extensions.presentAlert(title: nil,
                                        message: NSLocalizedString("alertErrorMsg", comment: "something went wrong"),
                                        imageName: "icons-error",
                                        viewController: self)
                         
            return
        }

        // Save the image data to a temporary file
        let temporaryFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("instagramImage.ig")

        do {
            try imageData.write(to: temporaryFileURL)
        } catch {
            // Error writing image data to a temporary file
            print("Error writing image data to a temporary file: \(error)")
            return
        }

        // Create an array of activity items with the temporary file URL
        let activityItems = [temporaryFileURL]

        let activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = self.view // so that iPads won't crash
        activityViewController.popoverPresentationController?.sourceRect = sender.frame

        // Exclude some activity types from the list (optional)
        activityViewController.excludedActivityTypes = [.addToReadingList,
                                                        .airDrop,
                                                        .assignToContact,
                                                        .copyToPasteboard,
                                                        .mail,
                                                        .message,
                                                        .openInIBooks,
                                                        .print,
                                                        .copyToPasteboard,
                                                        .markupAsPDF]

        // Present the view controller
        self.present(activityViewController, animated: true, completion: nil)
    }


}

extension EditVC: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        return filterImageNames.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "filtersCell", for: indexPath) as? FiltersCell {
            
            let imageName = filterImageNames[indexPath.item]
            if let image = UIImage(named: imageName) {
                cell.imageView.image = image
            }
            
            return cell
        } else {
            return UICollectionViewCell()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        filterImageView.translatesAutoresizingMaskIntoConstraints = false
        filterImageView.contentMode = .scaleAspectFill // Adjust this based on your image content mode
        filterImageView.isUserInteractionEnabled = true

        // Add the imageView to viewBg
        viewBg.addSubview(filterImageView)

        // Set constraints to match the position and size of templateView
        if let templateView = viewBg {
            filterImageView.centerXAnchor.constraint(equalTo: templateView.centerXAnchor).isActive = true
            filterImageView.centerYAnchor.constraint(equalTo: templateView.centerYAnchor).isActive = true
            filterImageView.widthAnchor.constraint(equalTo: templateView.widthAnchor).isActive = true
            filterImageView.heightAnchor.constraint(equalTo: templateView.heightAnchor).isActive = true
        }
        
        
        filterImageView.image = nil // Clear the previous filter result
        
        let filteredImage = viewBg?.takeScreenshot(with: 5.0) ?? UIImage()
        
        switch filterImageNames[indexPath.item] {
        case "None":
            // Remove the filterImageView from its superview
            filterImageView.removeFromSuperview()
        case "Posterize":
            filterImageView.image = filteredImage.addFilter(filter: .Posterize)
        case "Process":
            filterImageView.image = filteredImage.addFilter(filter: .Process)
        case "Invert":
            filterImageView.image = filteredImage.addFilter(filter: .Invert)
        case "SepiaTone":
            filterImageView.image = filteredImage.addFilter(filter: .SepiaTone)
        case "Chrome":
            filterImageView.image = filteredImage.addFilter(filter: .Chrome)
        case "Fade":
            filterImageView.image = filteredImage.addFilter(filter: .Fade)
        case "Instant":
            filterImageView.image = filteredImage.addFilter(filter: .Instant)
        case "Noir":
            filterImageView.image = filteredImage.addFilter(filter: .Noir)
        case "Tonal":
            filterImageView.image = filteredImage.addFilter(filter: .Tonal)
        default:
            break
        }
        
    }

}

extension UIImage {
    
    func addFilter(filter : FilterType) -> UIImage {
        let filter = CIFilter(name: filter.rawValue)
        // convert UIImage to CIImage and set as input
        let ciInput = CIImage(image: self)
        filter?.setValue(ciInput, forKey: "inputImage")
        // get output CIImage, render as CGImage first to retain proper UIImage scale
        let ciOutput = filter?.outputImage
        let ciContext = CIContext()
        let cgImage = ciContext.createCGImage(ciOutput!, from: (ciOutput?.extent)!)
        //Return the image
        return UIImage(cgImage: cgImage!)
    }
}

extension UIView {

    func scale(by scale: CGFloat) {
         self.contentScaleFactor = scale
         for subview in self.subviews {
             subview.scale(by: scale)
         }
     }

     func takeScreenshot(with scale: CGFloat? = nil) -> UIImage {
         let newScale = scale ?? UIScreen.main.scale
         self.scale(by: newScale)
         let format = UIGraphicsImageRendererFormat()
         format.scale = newScale
         //format.opaque = false // Set to true if the view has an opaque background
         let renderer = UIGraphicsImageRenderer(size: self.bounds.size, format: format)
         let image = renderer.image { rendererContext in
             self.layer.render(in: rendererContext.cgContext)
         }
         return image
     }
}

// MARK: - Google Ads Delegate
extension EditVC: GADBannerViewDelegate, GADFullScreenContentDelegate {
    
    //google ads delegate banner
    func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
      // Add banner to view and add constraints as above.
        
        let isPaid = UserDefaults.standard.bool(forKey: "isPaid")
        if (!isPaid) {
            
            //topConstraint.constant = 50
            //bgTokkers.layoutIfNeeded()
            
            addBannerViewToView(bannerView)
        
        } else {
            
            bannerView.isHidden = true
        }
    }
    
    func loadBannerAd() {
        //cos bannerView overlays first video
        //topConstraint.constant = 50
        //bgTokkers.layoutIfNeeded()
        
        // In this case, we instantiate the banner with desired ad size.
        
        bannerView = GADBannerView(adSize: GADAdSizeBanner)
        addBannerViewToView(bannerView)
        
        bannerView.adUnitID = AdUnitID.banner
        bannerView.rootViewController = self
        bannerView.load(GADRequest())
        bannerView.delegate = self
    }
    
    func addBannerViewToView(_ bannerView: GADBannerView) {
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bannerView)
        view.addConstraints(
          [NSLayoutConstraint(item: bannerView,
                              attribute: .bottom,
                              relatedBy: .equal,
                              toItem: view.safeAreaLayoutGuide,
                              attribute: .bottom,
                              multiplier: 1,
                              constant: 0),
           NSLayoutConstraint(item: bannerView,
                              attribute: .centerX,
                              relatedBy: .equal,
                              toItem: view,
                              attribute: .centerX,
                              multiplier: 1,
                              constant: 0)
          ])
       }
    
    //google ads delegate interstitial
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("Ad did dismiss full screen content.")
        //showAdWToPlayVideoCount += 1
        loadInterstitialAd()
    }
    
    func loadInterstitialAd() {
        
        loadBannerAd()

        let request = GADRequest()
        GADInterstitialAd.load(withAdUnitID: AdUnitID.interstitialAd,
                               request: request,
                               completionHandler: { [self] ad, error in
            if let error = error {
                print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                return
            }
            interstitial = ad
            interstitial?.fullScreenContentDelegate = self
        })
    }
    
    private func displayInterstitialAd() {

       if interstitial != nil {
           interstitial?.present(fromRootViewController: self)
       } else {
           print("interstitial ad wasn't ready")
       }
   }
}
