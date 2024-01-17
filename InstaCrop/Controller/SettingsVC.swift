//
//  SettingsVC.swift
//  InstaCrop
//
//  Created by Timchang Wuyep on 29/12/2023.
//

import UIKit
import MessageUI
import SVProgressHUD
import StoreKit
import NewYorkAlert

class SettingsVC: UIViewController, MFMailComposeViewControllerDelegate {
    

    @IBOutlet weak var featuresMsgLbl: UILabel!
    @IBOutlet weak var purchaseBtn: UIButton!
    @IBOutlet weak var restoreBtn: UIButton!
    @IBOutlet weak var moreAppsBtn: UIButton!
    
    let extensions = Extensions()
    var productLocalPrice: String?
    var productTitle: String?
    var productDesc: String?
    
    private var storeKitManager = StoreKitManager()
    private let productIds = ["com.nandatech.instacrop.pro"]
    
    override func viewDidLoad() {
        super.viewDidLoad()

        purchaseBtn.layer.cornerRadius = 5
        
        let localizedTitle = String.localizedStringWithFormat(NSLocalizedString("Purchase for %@",
                                                                                 comment: "Purchase button title"),
                                                              productLocalPrice ?? "$4.99")

        purchaseBtn.setTitle(localizedTitle, for: .normal)
        restoreBtn.setTitle(NSLocalizedString("restorePurchase", comment: "restore"), for: .normal)
        moreAppsBtn.setTitle(NSLocalizedString("moreApps", comment: "moreApps"), for: .normal)

        restoreBtn.layer.borderWidth = 1
        restoreBtn.layer.cornerRadius = 5
        restoreBtn.layer.borderColor = UIColor(named: "#8BE8E5")?.cgColor
        
        moreAppsBtn.layer.borderWidth = 1
        moreAppsBtn.layer.cornerRadius = 5
        moreAppsBtn.layer.borderColor = UIColor(named: "#8BE8E5")?.cgColor
        
        featuresMsgLbl.text = NSLocalizedString("proFeatures", comment: "pro features")
    
    }
    
    @IBAction func restoreBtnPressed(_ sender: UIButton) {
        
        SVProgressHUD.show()
        
        Task { @MainActor in
            
            await storeKitManager.restorePurchases()
        }
    }
    
    @IBAction func moreAppsBtnPressed(_ sender: UIButton) {
        
        let locale = Locale.current.regionCode ?? "US"
        
        UIApplication.shared.open(URL(string: "https://apps.apple.com/\(locale)/developer/nandatech-limited/id1594609723")!, options: [:], completionHandler: nil)
    }
    
    @IBAction func purchaseBtnPressed(_ sender: UIButton) {
        
        let alert = NewYorkAlertController(title: "\(productTitle ?? "Go Premium")",
                                           message: "\(productDesc ?? "No Ads")",
                                           style: .alert)
        
        alert.addImage(UIImage(named: "gift_icon"))

        let ok = NewYorkButton(title: productLocalPrice ?? "$4.99", style: .preferred) { _ in
            
            //purchase payments
            if (SKPaymentQueue.canMakePayments()) {
                // can make payments
                
                SVProgressHUD.show()
                
                Task { @MainActor in
                    
                    let products = await self.storeKitManager.retrieveProducts()
                    
                    for product in products {
                        
                        if product.id == "com.nandatech.instacrop.pro" {
                            
                            await self.storeKitManager.purchase(product)
                        }
                    }
                }
                
            } else {
                // can't make payments
                print("user cannot make payments.")
                
                self.extensions.presentAlert(title: "Device cannot make payments.",
                                             message: "Please enable payments for purchase",
                                             imageName: nil,
                                             viewController: self)
            }
        }
        
        let cancel = NewYorkButton(title: NSLocalizedString("alertCancel", comment: "cancel"), style: .cancel)

        alert.addButtons([ok,cancel])
        
        self.present(alert, animated: true)
    }
    
    @IBAction func emailBtnPressed(_ sender: UIButton) {
        
        showMailComposer()
    }
    
    // MARK: - Navigation
    func showMailComposer() {
        
        let countryLocale = NSLocale.current
        let countryCode = countryLocale.regionCode ?? "US"
        let country = (countryLocale as NSLocale).displayName(forKey: NSLocale.Key.countryCode, value: countryCode) ?? "US"
        
        //checking if device can send mail
        guard MFMailComposeViewController.canSendMail() else {
            //show alert informing user device cannot send mail
            //print("Cannot send mail")
            let alert = UIAlertController(title: NSLocalizedString("alertError", comment: "error"),
                                          message: NSLocalizedString("mailErrorMessage", comment: "mailErrorMessage") ,
                                          preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("alertCancel", comment: "alertCancel"), style: .cancel))
            
            self.present(alert, animated: true, completion: nil)
            return
        }
        
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = self
        composer.setToRecipients(["nandatech.info@gmail.com"])
        composer.setSubject("InstaCrop: \(country)")
        composer.setMessageBody("\(NSLocalizedString("mailBody", comment: "body")) \n\n\n\n\n\n\nV: \(version)", isHTML: false)
        
        present(composer, animated: true, completion: nil)
        
    }
    
    // MARK: - Mail Composer Delegate
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        
        if error != nil {
            
            //show error alert
            controller.dismiss(animated: true, completion: nil)
        }
        
        switch result {
            
        case .cancelled :
            
            print("Cancelled")
            dismiss(animated: true) {
                
                self.extensions.presentAlert(title: nil,
                                           message: NSLocalizedString("emailCancelled", comment: "emailCancelled"),
                                           imageName: nil,
                                           viewController: self)
            }
            
        case .failed :
            
            print("Failled to send")
            dismiss(animated: true) {
                
                self.extensions.presentAlert(title: nil,
                                               message: NSLocalizedString("emailFailed", comment: "emailFailed"),
                                               imageName: nil,
                                               viewController: self)
            }
            
        case .saved :
            
            print("Saved")
            dismiss(animated: true) {
                
                self.extensions.presentAlert(title: nil,
                                               message: NSLocalizedString("emailSaved", comment: "emailSaved"),
                                               imageName: nil,
                                               viewController: self)
            }
            
        case .sent :
            
            print("Email sent")
            dismiss(animated: true) {
                
                self.extensions.presentAlert(title: NSLocalizedString("emailSent", comment: "emailSent"),
                                               message: NSLocalizedString("emailSentBody", comment: "emailSentBody"),
                                               imageName: nil,
                                               viewController: self)
            }
            
        default:
            print("Default")
        }
        
    }

}
