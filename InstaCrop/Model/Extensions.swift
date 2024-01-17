//
//  Extensions.swift
//  InstaCrop
//
//  Created by Timchang Wuyep on 29/12/2023.
//

import Foundation
import UIKit
import Photos
import NewYorkAlert


enum AdUnitID {
    
    static let banner: String = "ca-app-pub-4544338503356333/6494269896" //live
    //Banner        "ca-app-pub-3940256099942544/2934735716"//test
              
    static let interstitialAd: String = "ca-app-pub-4544338503356333/2166397679" //live
    //Interstitial      "ca-app-pub-3940256099942544/4411468910"//test
                    
    //GADApplicationID live    ca-app-pub-4544338503356333~2367322628
    //GADApplicationID test    ca-app-pub-3940256099942544~1458002511
}

enum FilterType : String {
    
    case Chrome = "CIPhotoEffectChrome"
    case Fade = "CIPhotoEffectFade"
    case Instant = "CIPhotoEffectInstant"
    case Noir = "CIPhotoEffectNoir" //bw2
    case Process = "CIPhotoEffectProcess" //yellowish
    case Tonal = "CIPhotoEffectTonal" //bw
    case Invert = "CIColorInvert"
    case Posterize = "CIColorPosterize"
    case SepiaTone = "CISepiaTone"
}

struct Filter {
    
    let filterName: String
    var filterEffectValue: Any?
    var filterEffectValueName: String?
    
    init(filterName: String, filterEffectValue: Any? = nil, filterEffectValueName: String? = nil) {
        self.filterName = filterName
        self.filterEffectValue = filterEffectValue
        self.filterEffectValueName = filterEffectValueName
    }
    
}

struct Extensions {
    
    func presentAlert(title: String?, message: String?, imageName: String?, viewController: UIViewController) {
        
        let alert = NewYorkAlertController(title: title,
                                           message: message, style: .alert)
        
        if let img = imageName {
            
            alert.addImage(UIImage(named: img))
        }
        
        let cancel = NewYorkButton(title: NSLocalizedString("alertCancel", comment: "alertCancel"), style: .cancel)
        
        alert.addButton(cancel)
        alert.isTapDismissalEnabled = false
        
        viewController.present(alert, animated: true)
        
    }
    
    func setupShadow(viewBg: UIView) {
        // Set cell's background color and corner radius
        viewBg.backgroundColor = .systemBackground

        // Configure shadow properties
        viewBg.layer.shadowColor = UIColor.gray.cgColor
        viewBg.layer.shadowOffset = CGSize(width: 0, height: 2)
        viewBg.layer.shadowOpacity = 0.5
        viewBg.layer.shadowRadius = 4.0

        // Ensure the shadow respects the cell's bounds
        viewBg.layer.masksToBounds = false
    }
    
    func applyBlur(to image: UIImage, intensity: CGFloat) -> UIImage? {
        if let ciImage = CIImage(image: image) {
            let filter = CIFilter(name: "CIGaussianBlur")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            filter?.setValue(intensity * 10, forKey: kCIInputRadiusKey) // Adjust the blur radius

            if let outputImage = filter?.outputImage,
               let cgImage = CIContext().createCGImage(outputImage, from: ciImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        return nil
    }
    
    func saveImageToPhotosAlbum(_ image: UIImage, completion: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                completion(false, nil)
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    completion(success, error)
                }
            }
        }
    }
}
