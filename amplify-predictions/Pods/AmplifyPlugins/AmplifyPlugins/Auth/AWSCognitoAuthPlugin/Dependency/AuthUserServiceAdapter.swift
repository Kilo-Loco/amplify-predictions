//
// Copyright 2018-2020 Amazon.com,
// Inc. or its affiliates. All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Amplify
import AWSMobileClient

class AuthUserServiceAdapter: AuthUserServiceBehavior {

    let awsMobileClient: AWSMobileClientBehavior

    init(awsMobileClient: AWSMobileClientBehavior) {
        self.awsMobileClient = awsMobileClient
    }

    func fetchAttributes(request: AuthFetchUserAttributesRequest,
                         completionHandler: @escaping FetchUserAttributesCompletion) {
        awsMobileClient.getUserAttributes { result, error in
            guard error == nil else {
                if let awsMobileClientError = error as? AWSMobileClientError,
                    case .notSignedIn = awsMobileClientError {
                    let authError = AuthError.signedOut(
                        AuthPluginErrorConstants.fetchAttributeSignedOutError.errorDescription,
                        AuthPluginErrorConstants.fetchAttributeSignedOutError.recoverySuggestion, nil)
                    completionHandler(.failure(authError))
                } else {
                    let authError = AuthErrorHelper.toAuthError(error!)
                    completionHandler(.failure(authError))
                }
                return
            }
            guard let result = result else {
                // This should not happen, return an unknown error.
                let error = AuthError.unknown("Could not read result from fetchAttributes operation")
                completionHandler(.failure(error))
                return
            }
            let resultList = result.map { AuthUserAttribute(AuthUserAttributeKey(rawValue: $0.key), value: $0.value) }
            completionHandler(.success(resultList))
        }
    }

    func updateAttribute(request: AuthUpdateUserAttributeRequest,
                         completionHandler: @escaping UpdateUserAttributeCompletion) {

        let attribuetList = [request.userAttribute]
        updateAttributes(attributeList: attribuetList) { result in
            switch result {
            case .success(let updateAttributeResultDict):
                guard let updateResult = updateAttributeResultDict[request.userAttribute.key] else {
                    let error = AuthError.unknown("Could not read result from updateAttribute operation")
                    completionHandler(.failure(error))
                    return
                }
                completionHandler(.success(updateResult))
            case .failure(let error):
                completionHandler(.failure(error))

            }
        }

    }

    func updateAttributes(request: AuthUpdateUserAttributesRequest,
                          completionHandler: @escaping UpdateUserAttributesCompletion) {
        updateAttributes(attributeList: request.userAttributes, completionHandler: completionHandler)
    }

    func resendAttributeConfirmationCode(request: AuthAttributeResendConfirmationCodeRequest,
                                         completionHandler: @escaping ResendAttributeConfirmationCodeCompletion) {

        awsMobileClient.verifyUserAttribute(attributeName: request.attributeKey.rawValue) { result, error in

            guard error == nil else {
                if let awsMobileClientError = error as? AWSMobileClientError,
                    case .notSignedIn = awsMobileClientError {
                    let authError = AuthError.signedOut(
                        AuthPluginErrorConstants.resendAttributeCodeSignedOutError.errorDescription,
                        AuthPluginErrorConstants.resendAttributeCodeSignedOutError.recoverySuggestion, nil)
                    completionHandler(.failure(authError))
                } else {
                    let authError = AuthErrorHelper.toAuthError(error!)
                    completionHandler(.failure(authError))
                }
                return
            }

            guard let result = result else {
                // This should not happen, return an unknown error.
                let error = AuthError.unknown("""
                Could not read result from resendAttributeConfirmationCode operation
                """)
                completionHandler(.failure(error))
                return
            }
            let codeDeliveryDetails = result.toAuthCodeDeliveryDetails()
            completionHandler(.success(codeDeliveryDetails))
        }

    }

    func confirmAttribute(request: AuthConfirmUserAttributeRequest,
                          completionHandler: @escaping ConfirmAttributeCompletion) {

        awsMobileClient.confirmUpdateUserAttributes(
            attributeName: request.attributeKey.rawValue,
            code: request.confirmationCode) { error in
                guard let error = error else {
                    completionHandler(.success(()))
                    return
                }
                if let awsMobileClientError = error as? AWSMobileClientError,
                    case .notSignedIn = awsMobileClientError {
                    let authError = AuthError.signedOut(
                        AuthPluginErrorConstants.confirmAttributeSignedOutError.errorDescription,
                        AuthPluginErrorConstants.confirmAttributeSignedOutError.recoverySuggestion, nil)
                    completionHandler(.failure(authError))
                } else {
                    let authError = AuthErrorHelper.toAuthError(error)
                    completionHandler(.failure(authError))
                }
        }
    }

    func changePassword(request: AuthChangePasswordRequest,
                        completionHandler: @escaping ChangePasswordCompletion) {
        awsMobileClient.changePassword(
            currentPassword: request.oldPassword,
            proposedPassword: request.newPassword) { error in
                guard let error = error else {
                    completionHandler(.success(()))
                    return
                }
                if let awsMobileClientError = error as? AWSMobileClientError,
                    case .notSignedIn = awsMobileClientError {
                    let authError = AuthError.signedOut(
                        AuthPluginErrorConstants.changePasswordSignedOutError.errorDescription,
                        AuthPluginErrorConstants.changePasswordSignedOutError.recoverySuggestion, nil)
                    completionHandler(.failure(authError))
                } else {
                    let authError = AuthErrorHelper.toAuthError(error)
                    completionHandler(.failure(authError))
                }
        }

    }

    private func updateAttributes(attributeList: [AuthUserAttribute],
                                  completionHandler: @escaping UpdateUserAttributesCompletion) {

        let attributeMap = attributeList.reduce(into: [String: String]()) {
            $0[$1.key.rawValue] = $1.value
        }
        awsMobileClient.updateUserAttributes(attributeMap: attributeMap) { result, error in
            guard error == nil else {
                if let awsMobileClientError = error as? AWSMobileClientError,
                    case .notSignedIn = awsMobileClientError {
                    let authError = AuthError.signedOut(
                        AuthPluginErrorConstants.updateAttributeSignedOutError.errorDescription,
                        AuthPluginErrorConstants.updateAttributeSignedOutError.recoverySuggestion, nil)
                    completionHandler(.failure(authError))
                } else {
                    let authError = AuthErrorHelper.toAuthError(error!)
                    completionHandler(.failure(authError))
                }
                return
            }

            guard let result = result else {
                // This should not happen, return an unknown error.
                let error = AuthError.unknown("Could not read result from verifyUserAttribute operation")
                completionHandler(.failure(error))
                return
            }

            var finalResult = [AuthUserAttributeKey: AuthUpdateAttributeResult]()
            for item in result {
                if let attribute = item.attributeName {
                    let authCodeDeliveryDetails = item.toAuthCodeDeliveryDetails()
                    let nextStep = AuthUpdateAttributeStep.confirmAttributeWithCode(authCodeDeliveryDetails, nil)
                    let updateAttributeResult = AuthUpdateAttributeResult(isUpdated: false,
                                                                          nextStep: nextStep)
                    finalResult[AuthUserAttributeKey(rawValue: attribute)] = updateAttributeResult
                }
            }
            // Check if all items are added to the dictionary
            for item in attributeList where finalResult[item.key] == nil {
                let updateAttributeResult = AuthUpdateAttributeResult(isUpdated: true, nextStep: .done)
                finalResult[item.key] = updateAttributeResult
            }
            completionHandler(.success(finalResult))
        }
    }
}
