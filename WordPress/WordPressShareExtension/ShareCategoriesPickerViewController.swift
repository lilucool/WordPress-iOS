import Foundation
import CocoaLumberjack
import WordPressKit
import WordPressShared

class ShareCategoriesPickerViewController: UIViewController {

    // MARK: - Public Properties

    @objc var onValueChanged: (([RemotePostCategory]) -> Void)?

    // MARK: - Private Properties

    fileprivate let tableView = UITableView(frame: .zero, style: .grouped)

    /// Categories originally passed into init()
    ///
    fileprivate let originalCategories: [RemotePostCategory]

    /// Selected categories
    ///
    fileprivate var selectedCategories: [RemotePostCategory]?

    /// SiteID to fetch tags for
    ///
    fileprivate let siteID: Int

    /// Apply Bar Button
    ///
    fileprivate lazy var applyButton: UIBarButtonItem = {
        let applyTitle = NSLocalizedString("Apply", comment: "Apply action on the app extension tags picker screen. Saves the selected tags for the post.")
        let button = UIBarButtonItem(title: applyTitle, style: .plain, target: self, action: #selector(applyWasPressed))
        button.accessibilityIdentifier = "Apply Button"
        return button
    }()

    /// Cancel Bar Button
    ///
    fileprivate lazy var cancelButton: UIBarButtonItem = {
        let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel action on the app extension tags picker screen.")
        let button = UIBarButtonItem(title: cancelTitle, style: .plain, target: self, action: #selector(cancelWasPressed))
        button.accessibilityIdentifier = "Cancel Button"
        return button
    }()

    /// Refresh Control
    ///
    fileprivate lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        // FIXME: Enable this
        //refreshControl.addTarget(self, action: #selector(pullToRefresh(sender:)), for: .valueChanged)
        return refreshControl
    }()

    /// Activity spinner used when loading sites
    ///
    fileprivate lazy var loadingActivityIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: .gray)

    /// No results view
    ///
    @objc lazy var noResultsView: WPNoResultsView = {
        let title = NSLocalizedString("No available Categories", comment: "A short message that informs the user no categories could be loaded in the share extension.")
        return WPNoResultsView(title: title, message: nil, accessoryView: nil, buttonTitle: nil)
    }()

    /// Loading view
    ///
    @objc lazy var loadingView: WPNoResultsView = {
        let title = NSLocalizedString("Fetching Categories...", comment: "A short message to inform the user data for their categories are being fetched.")
        return WPNoResultsView(title: title, message: nil, accessoryView: loadingActivityIndicatorView, buttonTitle: nil)
    }()

    var rowCountForCategories: Int {
        return selectedCategories?.count ?? 0
    }

    // MARK: - Initializers

    init(siteID: Int, categories: [RemotePostCategory]?) {
        self.originalCategories = categories ?? []
        self.siteID = siteID
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize Interface
        setupNavigationBar()
        setupTableView()
        setupConstraints()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadCategories()
    }

    // MARK: - Setup Helpers

    fileprivate func setupNavigationBar() {
        navigationItem.hidesBackButton = true
        navigationItem.leftBarButtonItem = cancelButton
        navigationItem.rightBarButtonItem = applyButton
    }

    fileprivate func setupTableView() {
        // FIXME: fix this setup
        WPStyleGuide.configureColors(for: view, andTableView: tableView)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Constants.cellReuseIdentifier)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNonzeroMagnitude))
        reloadTableData()
    }

    fileprivate func setupConstraints() {
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}

// MARK: - Actions

extension ShareCategoriesPickerViewController {
    @objc func cancelWasPressed() {
        _ = navigationController?.popViewController(animated: true)
    }

    @objc func applyWasPressed() {
        let categories = selectedCategories ?? []
        if categories != originalCategories {
            onValueChanged?(categories)
        }
        _ = navigationController?.popViewController(animated: true)
    }
}

// MARK: - Tags Loading

fileprivate extension ShareCategoriesPickerViewController {
    func loadCategories() {
        let service = AppExtensionsService()
        service.fetchCategoriesForSite(siteID, onSuccess: { categories in
            let categories = categories.flatMap { return $0 }
            self.selectedCategories = categories
        }, onFailure: { error in
            self.categoriesFailedLoading(error)
        })
    }

    func categoriesFailedLoading(_ error: Error?) {
        if let error = error {
            DDLogError("Error loading categories: \(error)")
        }
        // FIXME: e.g. dataSource = FailureDataSource()
    }
}

// MARK: - UITableView DataSource Conformance

extension ShareCategoriesPickerViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rowCountForCategories
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Constants.cellReuseIdentifier)!
        configureCategoryCell(cell)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return Constants.defaultRowHeight
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        WPStyleGuide.configureTableViewSectionHeader(view)
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return nil
    }

    func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        WPStyleGuide.configureTableViewSectionFooter(view)
    }
}

// MARK: - UITableView Delegate Conformance

extension ShareCategoriesPickerViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // FIXME: Do something here!
    }
}

// MARK: - Misc private helpers

fileprivate extension ShareCategoriesPickerViewController {
    func reloadTableData() {
        tableView.reloadData()
    }

    func configureCategoryCell(_ cell: UITableViewCell) {
        WPStyleGuide.Share.configureModuleCell(cell)
    }
}

// MARK: - Constants

fileprivate extension ShareCategoriesPickerViewController {
    struct Constants {
        static let cellReuseIdentifier  = String(describing: ShareCategoriesPickerViewController.self)
        static let defaultRowHeight     = CGFloat(44.0)
        static let emptyCount           = 0
        static let flashAnimationLength = 0.2
    }
}
