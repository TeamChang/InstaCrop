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

    // Instagram-style gradient (matches the app icon) behind the main CTA button
    private let selectBtnGradient = CAGradientLayer()

    override func viewDidLoad() {
        super.viewDidLoad()

        imagePicker.delegate = self
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(openImagePicker))
        bgImageView.addGestureRecognizer(tapGesture)
        bgImageView.isUserInteractionEnabled = true

        // Make the button have oval edges
        selectBtn.layer.cornerRadius = selectBtn.frame.size.height / 2
        selectBtn.clipsToBounds = true

        setupSelectBtnGradient()

        getProductsInfo()

    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        selectBtnGradient.frame = selectBtn.bounds
        selectBtnGradient.cornerRadius = selectBtn.layer.cornerRadius
    }

    private func setupSelectBtnGradient() {

        // Blue -> purple -> magenta -> orange, same diagonal sweep as the app icon
        selectBtnGradient.colors = [
            UIColor(red: 0.251, green: 0.365, blue: 0.902, alpha: 1).cgColor, // #405DE6
            UIColor(red: 0.514, green: 0.227, blue: 0.706, alpha: 1).cgColor, // #833AB4
            UIColor(red: 0.757, green: 0.208, blue: 0.518, alpha: 1).cgColor, // #C13584
            UIColor(red: 0.969, green: 0.467, blue: 0.216, alpha: 1).cgColor  // #F77737
        ]
        selectBtnGradient.locations = [0, 0.35, 0.65, 1]
        selectBtnGradient.startPoint = CGPoint(x: 0, y: 0)
        selectBtnGradient.endPoint = CGPoint(x: 1, y: 1)
        selectBtnGradient.cornerRadius = selectBtn.layer.cornerRadius

        selectBtn.layer.insertSublayer(selectBtnGradient, at: 0)
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
    
    @objc func openImagePicker() {
       
        //imagePicker.allowsEditing = true //cause full image not selected. its pre cropped
        imagePicker.sourceType = .photoLibrary
        present(imagePicker, animated: true, completion: nil)
   }
    
    @IBAction func selectBtnPressed(_ sender: UIButton) {
        
        openImagePicker()
    }
    
    // Delegate method called when the user picks an image
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let editedImage = info[.originalImage] as? UIImage {
            
            //cause full image not selected. its pre cropped in edited image
            
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

