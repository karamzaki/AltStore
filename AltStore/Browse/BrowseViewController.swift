//
//  BrowseViewController.swift
//  AltStore
//
//  Created by Riley Testut on 7/15/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit

import Roxas

class BrowseViewController: UICollectionViewController
{
    private lazy var dataSource = self.makeDataSource()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.collectionView.dataSource = self.dataSource
        self.collectionView.prefetchDataSource = self.dataSource
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        self.fetchApps()
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        let collectionViewLayout = self.collectionViewLayout as! UICollectionViewFlowLayout
        collectionViewLayout.itemSize.width = self.view.bounds.width
    }
}

private extension BrowseViewController
{
    func makeDataSource() -> RSTFetchedResultsCollectionViewPrefetchingDataSource<App, UIImage>
    {
        let fetchRequest = App.fetchRequest() as NSFetchRequest<App>
        fetchRequest.relationshipKeyPathsForPrefetching = [#keyPath(InstalledApp.app)]
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \App.name, ascending: false)]
        fetchRequest.predicate = NSPredicate(format: "%K != %@", #keyPath(App.identifier), App.altstoreAppID)
        fetchRequest.returnsObjectsAsFaults = false
        
        let dataSource = RSTFetchedResultsCollectionViewPrefetchingDataSource<App, UIImage>(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext)
        dataSource.cellConfigurationHandler = { [weak self] (cell, app, indexPath) in
            guard let `self` = self else { return }
            
            let cell = cell as! BrowseCollectionViewCell
            cell.nameLabel.text = app.name
            cell.developerLabel.text = app.developerName
            cell.subtitleLabel.text = app.subtitle
            cell.imageNames = Array(app.screenshotNames.prefix(3))
            cell.appIconImageView.image = UIImage(named: app.iconName)
            
            cell.actionButton.tag = indexPath.item
            cell.actionButton.activityIndicatorView.style = .white
            
            // Explicitly set to false to ensure we're starting from a non-activity indicating state.
            // Otherwise, cell reuse can mess up some cached values.
            cell.actionButton.isIndicatingActivity = false
            
            let tintColor = app.tintColor ?? self.collectionView.tintColor!
            cell.tintColor = tintColor
            cell.actionButton.progressTintColor = tintColor
            
            if app.installedApp == nil
            {
                cell.actionButton.setTitle(NSLocalizedString("FREE", comment: ""), for: .normal)
                cell.actionButton.setTitleColor(.altGreen, for: .normal)
                cell.actionButton.backgroundColor = UIColor.altGreen.withAlphaComponent(0.1)
                
                if let progress = AppManager.shared.installationProgress(for: app)
                {
                    cell.actionButton.progress = progress
                    cell.actionButton.isIndicatingActivity = true
                    cell.actionButton.activityIndicatorView.isUserInteractionEnabled = false
                    cell.actionButton.isUserInteractionEnabled = true
                }
                else
                {
                    cell.actionButton.progress = nil
                    cell.actionButton.isIndicatingActivity = false
                }
            }
            else
            {
                cell.actionButton.setTitle(NSLocalizedString("OPEN", comment: ""), for: .normal)
                cell.actionButton.setTitleColor(.white, for: .normal)
                cell.actionButton.backgroundColor = .altGreen
            }
        }
        
        return dataSource
    }
    
    func fetchApps()
    {
        AppManager.shared.fetchApps() { (result) in
            do
            {
                let apps = try result.get()
                try apps.first?.managedObjectContext?.save()
            }
            catch
            {
                DispatchQueue.main.async {
                    let toastView = RSTToastView(text: NSLocalizedString("Failed to Fetch Apps", comment: ""), detailText: error.localizedDescription)
                    toastView.tintColor = .altGreen
                    toastView.show(in: self.navigationController?.view ?? self.view, duration: 2.0)
                }
            }
        }
    }
}

private extension BrowseViewController
{
    @IBAction func performAppAction(_ sender: ProgressButton)
    {
        let indexPath = IndexPath(item: sender.tag, section: 0)
        let app = self.dataSource.item(at: indexPath)
        
        if let installedApp = app.installedApp
        {
            self.open(installedApp)
        }
        else
        {
            self.install(app, at: indexPath)
        }
    }
    
    func install(_ app: App, at indexPath: IndexPath)
    {
        let previousProgress = AppManager.shared.installationProgress(for: app)
        guard previousProgress == nil else {
            previousProgress?.cancel()
            return
        }
        
        _ = AppManager.shared.install(app, presentingViewController: self) { (result) in
            DispatchQueue.main.async {
                switch result
                {
                case .failure(OperationError.cancelled): break // Ignore
                case .failure(let error):
                    let toastView = RSTToastView(text: "Failed to install \(app.name)", detailText: error.localizedDescription)
                    toastView.tintColor = .altGreen
                    toastView.show(in: self.navigationController!.view, duration: 2)
                
                case .success(let installedApp): print("Installed app:", installedApp.app.identifier)
                }
                
                self.collectionView.reloadItems(at: [indexPath])
            }
        }
        
        self.collectionView.reloadItems(at: [indexPath])
    }
    
    func open(_ installedApp: InstalledApp)
    {
        UIApplication.shared.open(installedApp.openAppURL)
    }
}
