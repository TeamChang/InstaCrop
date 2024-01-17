//
//  ViewController.swift
//  InstaCrop
//
//  Created by Timchang Wuyep on 21/12/2023.
//

import UIKit

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var bgImageView: UIImageView!
    @IBOutlet weak var selectBtn: UIButton!
    
    private var storeKitManager = StoreKitManager()
    let imagePicker = UIImagePickerController()
    var image: UIImage?
    
    var productLocalPrice = ""
    var productTitle = ""
    var productDesc = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imagePicker.delegate = self
        
        // Make the button have oval edges
        selectBtn.layer.cornerRadius = selectBtn.frame.size.height / 2
        selectBtn.clipsToBounds = true
        
        getProductsInfo()
        
    }
    
    func getProductsInfo() {
        
        Task { @MainActor in
            
            let products = await self.storeKitManager.retrieveProducts()
            
            for product in products {
                
                productLocalPrice = product.displayPrice
                productTitle = product.displayName
                productDesc = product.description
           
            }
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {

            case "toEditVC":
                
                let destinationVC = segue.destination as! EditVC
                    
                destinationVC.editImage = image
            
        case "toSettings":
            
            let destinationVC = segue.destination as! SettingsVC
                
            destinationVC.productLocalPrice = productLocalPrice
            destinationVC.productTitle = productTitle
            destinationVC.productDesc = productDesc
            
            default:
                break
            }
    }
    
    @IBAction func selectBtnPressed(_ sender: UIButton) {
        
        // Open the image picker when the button is tapped
        //imagePicker.allowsEditing = true
        imagePicker.sourceType = .photoLibrary
        present(imagePicker, animated: true, completion: nil)
    }
    
    // Delegate method called when the user picks an image
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let editedImage = info[.originalImage] as? UIImage {
            
            image = editedImage
            
//            let squaredImage = squareImage(editedImage)
//            bgImageView.image = squaredImage
        }

        dismiss(animated: true, completion: {
            
            self.performSegue(withIdentifier: "toEditVC", sender: self)
        })
    }

    // Function to square the image
//    func squareImage(_ image: UIImage) -> UIImage {
//        let size = min(image.size.width, image.size.height)
//        let origin = CGPoint(x: (image.size.width - size) / 2, y: (image.size.height - size) / 2)
//        let rect = CGRect(origin: origin, size: CGSize(width: size, height: size))
//
//        if let cgImage = image.cgImage?.cropping(to: rect) {
//            return UIImage(cgImage: cgImage)
//        }
//
//        return image
//    }

}

