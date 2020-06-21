//
//  ViewController.swift
//  amplify-predictions
//
//  Created by Kyle Lee on 6/20/20.
//  Copyright © 2020 Kilo Loco. All rights reserved.
//

import Amplify
import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        fetchCurrentAuthSession()
        
        let imageUrl = URL(string: "https://3v6x691yvn532gp2411ezrib-wpengine.netdna-ssl.com/wp-content/uploads/2019/05/imagetext02.jpg")!
        detectText(imageUrl)
    }

    func fetchCurrentAuthSession() {
        _ = Amplify.Auth.fetchAuthSession { result in
            switch result {
            case .success(let session):
                print("Is user signed in - \(session.isSignedIn)")
            case .failure(let error):
                print("Fetch session failed with error \(error)")
            }
        }
    }
    
    func detectText(_ image: URL) {
        _ = Amplify.Predictions.identify(type: .detectText(.plain), image: image, options: PredictionsIdentifyRequest.Options(), listener: { (event) in
            switch event {
            case .success(let result):
                print(result)
                
            case .failure(let error):
                print(error)
            }
        })
    }

}

