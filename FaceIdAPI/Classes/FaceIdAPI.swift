//
//  FaceIdAPI.swift
//  FaceId
//
//  Created by Roman on 08.11.16.
//  Copyright © 2016 i.Point. All rights reserved.
//

import Foundation
import UIKit

enum FaceIdAPIError: Error {
    case noConnection
    case apiError(message: String)
    case setPersonInfoError(message: String)
    case addPersonError(message: String)
    
    var description: String {
        switch self {
            case .noConnection: return "Unable to connect to API. Please, check an internet connection."
            case let .apiError(message): return "API Error: \(message)"
            case let .setPersonInfoError(message): return "Unable to set person info: \(message)"
            case let .addPersonError(message): return "Unable to add new person: \(message)"
        }
    }
}

class FaceIdAPI  {
    
    var host: String
    var user: String
    var password: String
    var clientId: String
    var clientSecret: String
    
    var accessToken: String?
    
    init(host: String, user: String, password: String, clientId: String, clientSecret: String) {
        self.host = host
        self.user = user
        self.password = password
        self.clientId = clientId
        self.clientSecret = clientSecret
    }
    
    func decodeJsonData(data: Data?) -> [String:AnyObject]? {
        var dict: [String:AnyObject]?
        do {
            dict = try JSONSerialization.jsonObject(with: data!, options: []) as? [String:AnyObject]
        } catch {
            dict = nil
        }
        return dict
    }
    
    func encodeJsonData(json: [String:AnyObject]) -> Data? {
        var data: Data?
        do {
            data = try JSONSerialization.data(withJSONObject: json, options: [])
        } catch {
            data = nil
        }
        return data
    }
    
    func login(callback: @escaping (_ error: FaceIdAPIError?) -> Void) {
        let url = URL(string: "http://\(self.host)/o/token/")!
        let session = URLSession.shared
        var request = URLRequest(url: url)
        
        let body = "grant_type=password&username=\(user)&password=\(password)&client_id=\(clientId)&client_secret=\(clientSecret)"
        
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // The magic...set the HTTP request method to POST
        request.httpMethod = "POST"
        
        // Add data to the body
        request.httpBody = body.data(using: String.Encoding.utf8)

        // Create the task that will send our login request (asynchronously)
        let task = session.dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            // Do something with the HTTP response
            if let err = error {
                print("Login error: " + err.localizedDescription)
                callback(FaceIdAPIError.noConnection)
            } else {
                //print(data!)
                if let dict = self.decodeJsonData(data: data) {
                    self.accessToken = dict["access_token"] as? String
                    if let token = self.accessToken {
                        print("Access token: " + token)
                    }
                }
                callback(nil)
            }
        })
        
        // Start the task on a background thread
        task.resume()
    }
    
    private func doPost(url:String, body: Data?, callback: @escaping (_ data: [String:AnyObject]?, _ error: Error?) -> Void) {
        if let token = self.accessToken {
            let session = URLSession.shared
            var request = URLRequest(url: URL(string: url)!)
            
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
            
            request.httpMethod = "POST"
            
            // Add data to the body
            request.httpBody = body
            
            // Create the task that will send our login request (asynchronously)
            let task = session.dataTask(with: request, completionHandler: { (data, response, error) -> Void in
                // Do something with the HTTP response
                if error == nil {
                    callback(self.decodeJsonData(data: data), nil)
                } else {
                    callback(nil, error)
                }
            })
            
            // Start the task on a background thread
            task.resume()
        }
    }
    
    private func postJson(url:String, body: Data?, callback: @escaping (_ data: [String:AnyObject]?, _ error: Error?) -> Void) {
        if self.accessToken == nil {
            self.login() { err in
                if err == nil {
                    self.doPost(url: url, body: body, callback: callback)
                } else {
                    callback(nil, err)
                }
            }
        } else {
            self.doPost(url: url, body: body, callback: callback)
        }
    }
    
    func getPersonInfo(id: Int, callback: @escaping (_ data: [String:AnyObject]?, _ error: FaceIdAPIError?) -> Void) {
        let url: String = "http://\(self.host)/api/getPersonInfo/\(id)"
        let body: Data? = nil
        postJson(url: url, body: body) { data, error in
            if error == nil {
                callback(data, nil)
            } else {
                callback(data, FaceIdAPIError.apiError(message: error!.localizedDescription))
            }
            
        }
    }
    
    func getPersonId(image: UIImage, callback: @escaping (_ id: Int?, _ error: FaceIdAPIError?) -> Void) {
        let url: String = "http://\(self.host)/api/getPersonId"
        let body: Data? = encodeJsonData(json: ["image": image.encode() as AnyObject])
        postJson(url: url, body: body) { data, error in
            if error == nil {
                if let dict = data {
                    if let err = dict["err"] {
                        print("getPersonId error: \(err)")
                        callback(nil, FaceIdAPIError.apiError(message: err as! String))
                    } else {
                        if let id = dict["id"] as? Int {
                            if id>=0 {
                                callback(id, nil)
                            } else {
                                callback(nil, nil)
                            }
                        } else {
                            callback(nil, nil)
                        }
                    }
                }
            } else {
                callback(nil, FaceIdAPIError.apiError(message: error!.localizedDescription))
            }
        }
    }
    
    func setPersonInfo(id:Int, info: [String:AnyObject], callback: @escaping (_ data: [String:AnyObject]?, _ error: FaceIdAPIError?) -> Void) {
        let url: String = "http://\(self.host)/api/setPersonInfo/\(id)"
        let body: Data? = encodeJsonData(json: info)
        postJson(url: url, body: body) { data, error in
            if error == nil {
                callback(data, nil)
            } else {
                callback(nil, FaceIdAPIError.setPersonInfoError(message: error!.localizedDescription))
            }
        }
    }
    
    func addPerson(name: String, images: [String], callback: @escaping (_ id: Int?, _ error: FaceIdAPIError?) -> Void) {
        let url: String = "http://\(self.host)/api/addPerson"
        let body: Data? = encodeJsonData(json: ["images": images as AnyObject])
        postJson(url: url, body: body) { data, error in
            if error == nil {
                if let dict = data {
                    if let err = dict["err"] as? String {
                        callback(nil, FaceIdAPIError.addPersonError(message: err))
                    } else {
                        if let id = dict["id"] as? Int {
                            self.setPersonInfo(id: id, info: ["name": name as AnyObject]) { info, err in
                                if err == nil {
                                    if (info != nil) {
                                        if let msg = info!["err"] as? String {
                                            callback(nil, FaceIdAPIError.addPersonError(message: msg))
                                        } else {
                                            callback(id, nil)
                                        }
                                    } else {
                                        callback(id, FaceIdAPIError.addPersonError(message: "Unknown error"))
                                    }
                                } else {
                                    callback(nil, err)
                                }
                            }
                        } else {
                            callback(nil, FaceIdAPIError.addPersonError(message: "Unknown error"))
                        }
                    }
                } else {
                    callback(nil, FaceIdAPIError.addPersonError(message: "Unknown error"))
                }
            } else {
                callback(nil, FaceIdAPIError.addPersonError(message: error!.localizedDescription))
            }            
        }
    }
    
}

extension UIImage {
    
    internal func encode() -> String {
        let imageData: Data? = UIImageJPEGRepresentation(self, 1)
        
        
        let base64String = imageData!.base64EncodedString()
        return base64String
    }
    
    static func decode(base64String: String) -> UIImage? {
        let decodedData = Data(base64Encoded: base64String)
        return UIImage(data: decodedData!)
    }
    
    internal func compress(size: CGFloat) -> UIImage {
        let newSize = CGSize(width: self.size.width * size, height: self.size.height * size)
        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        self.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let newImage=UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage!
    }
    
}
