//
//  StoreKitManager.swift
//  InstaCrop
//
//  Created by Timchang Wuyep on 08/01/2024.
//

import Foundation
import StoreKit
import SVProgressHUD

enum StoreKitError: Error {
    case failedVerification
    case unknownError
}

enum PurchaseStatus {
    case success(String)
    case pending
    case cancelled
    case failed(Error)
    case unknown
}

protocol StoreKitManageable {
    //func retrieveProducts() async
    func retrieveProducts() async -> [Product]
    func purchase(_ item: Product) async
    func verifyPurchase<T>(_ verificationResult: VerificationResult<T>) throws -> T
    func transactionStatusStream() -> Task<Void, Error>
}

class StoreKitManager: ObservableObject {
    
    @Published var storeProducts: [Product] = []
    @Published var transactionCompletionStatus : Bool = false
    
    private let productIds = ["com.nandatech.instacrop.pro"]
    
    private(set) var purchaseStatus: PurchaseStatus = .unknown
    private(set) var transactionListener: Task<Void, Error>?
    
    init() {
        transactionListener = transactionStatusStream()
        Task {
            await retrieveProducts()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    func retrieveProducts() async -> [Product] {
        do {
            let products = try await Product.products(for: productIds)
            self.storeProducts = products
            
            return products
            
        } catch {
            print(error)
            return []
        }
    }
    
    /// Purchase the in-app product
    func purchase(_ item: Product) async {
        do {
            let result = try await item.purchase()
            
            switch result {
            case .success(let verification):
                print("Purchase was a success, now it can be verified.")
                do {
                    let verificationResult = try verifyPurchase(verification)
                    purchaseStatus = .success(verificationResult.productID)
                    // set userdefault to true
                    UserDefaults.standard.set(true, forKey: "isPaid")
                    DispatchQueue.main.async {
                        SVProgressHUD.dismiss()
                    }
                    print("productID \(verificationResult.productID)")
                    await verificationResult.finish()
                    transactionCompletionStatus = true
                } catch {
                    purchaseStatus = .failed(error)
                    UserDefaults.standard.set(false, forKey: "isPaid")
                    DispatchQueue.main.async {
                        SVProgressHUD.dismiss()
                    }
                    print("productID nil")
                    transactionCompletionStatus = true
                }
            case .pending:
                print("Transaction is pending for some action from the users related to the account")
                purchaseStatus = .pending
                UserDefaults.standard.set(false, forKey: "isPaid")
                DispatchQueue.main.async {
                    SVProgressHUD.dismiss()
                }
                print("productID nil")
                transactionCompletionStatus = false
            case .userCancelled:
                print("User cancelled the transaction")
                purchaseStatus = .cancelled
                UserDefaults.standard.set(false, forKey: "isPaid")
                DispatchQueue.main.async {
                    SVProgressHUD.dismiss()
                }
                print("productID nil")
                transactionCompletionStatus = false
            default:
                print("Unknown error")
                purchaseStatus = .failed(StoreKitError.unknownError)
                UserDefaults.standard.set(false, forKey: "isPaid")
                DispatchQueue.main.async {
                    SVProgressHUD.dismiss()
                }
                print("productID nil")
                transactionCompletionStatus = false
            }
        } catch {
            print(error)
            purchaseStatus = .failed(error)
            UserDefaults.standard.set(false, forKey: "isPaid")
            print("productID nil")
            transactionCompletionStatus = false
            DispatchQueue.main.async {
                SVProgressHUD.dismiss()
            }
        }
    }
    
    func restorePurchases() async {
        
        try? await AppStore.sync()

        await SVProgressHUD.dismiss()
        
        for await result in Transaction.currentEntitlements {
            if case let .verified(transaction) = result {
                // ... restore purchases
                print(transaction)
                UserDefaults.standard.set(true, forKey: "isPaid")
                print("UserDefaults is true")
               
            } else {
                UserDefaults.standard.set(false, forKey: "isPaid")
                print("UserDefaults is false")
            }
        }
    }
    
    func verifyPurchase<T>(_ verificationResult: VerificationResult<T>) throws -> T {
        switch verificationResult {
        case .unverified(_, let error):
            throw error //Successful purchase but transaction/receipt can't be verified due to some conditions like jailbroken phone
        case .verified(let result):
            return result  // Successful purchase
        }
    }
    
    /// Handle Interruptions
    /// gets called during renew
    func transactionStatusStream() -> Task<Void, Error> {
        Task.detached(priority: .background) { @MainActor [weak self] in
            do {
                
                for await result in Transaction.updates {
                    let transaction = try self?.verifyPurchase(result)
                    self?.purchaseStatus = .success(transaction?.productID ?? "Unknown Product Id")
                    print("purchaseStatus: \(transaction?.productID)")
                    print(self?.purchaseStatus)
                    UserDefaults.standard.set(true, forKey: "isPaid")
                    print("UserDefaults: \(UserDefaults.standard.string(forKey: "isPaid"))")
                    self?.transactionCompletionStatus = true
                    await transaction?.finish()
                }
            } catch {
                self?.transactionCompletionStatus = true
                self?.purchaseStatus = .failed(error)
                UserDefaults.standard.set(false, forKey: "isPaid")
            }
        }
    }
    
    /// Unlocking in-app features -
    func inAppEntitlements() async {
        // It return the array of all transactions
        for await result in Transaction.all {
            dump(result.payloadData)
        }
    }
    
}
