//
//  AudioManagerDelegate.swift
//  VoxAI
//
//  Created by Jeffery Abbott on 11/8/24.
//


protocol AudioManagerDelegate: AnyObject {
    func audioManagerDidStartRecording()
    func audioManagerDidStopRecording()
    func audioManager(didReceiveError: Error)
}
