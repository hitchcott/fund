issues = new ReactiveVar null

Router.route '/create',
  template: 'issue_finder'
  data:
    issues: -> issues.get()

  onBeforeAction: ->
    githubToken = Meteor.user()?.services?.github?.accessToken
    if githubToken
      $.get "https://api.github.com/issues",
        access_token : githubToken
        filter: 'all'
        state: 'open'
      .done (data) ->
        # TODO: fiter-out private issues repos in API request instead of on client
        publicIssues = _.filter data, (issue) -> issue.repository.private is false
        issues.set publicIssues
    @next()

Template.issue_finder.helpers
  tableSettings: ->
    collection: issues.get()
    rowClass: (row) -> 'success' if App.cols.Funds.findOne 'issue.id' : row.id

    rowsPerPage : 30
    fields: [
      key: 'created_at'
      label: 'Created'
    ,
      key: 'repository.full_name'
      label: "Repo Name"
    ,
      label: 'Issue'
      key: 'title'
      tmpl: Template['issue_finder_issue_cell']
    ,
      label: 'Comments'
      key: 'comments'
      sort: 'desc'
    ]

createFund = (thisIssue) ->
  exsistingFund = App.cols.Funds.findOne {creatorId: Meteor.userId() , 'issue.id': thisIssue.id}
  if exsistingFund
    Router.go 'fund' , _id: exsistingFund._id
  else
    confirmModal = EZModal
      title: 'Please Confirm'
      bodyHtml: """
      <p>You are about to create a new fund for:</p>
      <h3><small>Issue</small> #{thisIssue.number} <a href="#{thisIssue.html_url}" target="_blank">#{thisIssue.title}</a></h3>
      <h3><small>Repository</small> <a href="#{thisIssue.repository.html_url}" target="_blank">#{thisIssue.repository.full_name}</a></h3>
      """
      leftButtons: [
        html: 'Cancel'
      ]
      rightButtons: [
        html: 'Confirm'
        color: 'success'
        fn: (e, tmpl) ->
          confirmModal.modal('hide')
          waitModal = EZModal
            template: 'issue_finder_loading_bar'
          Meteor.call 'createFund',
            issue_number: thisIssue.number
            repo_name: thisIssue.repository.full_name
          , (err, fundId) ->
            waitModal.modal('hide')
            if err
              EZModal
                title: "Error!"
                body: err.error
            else
              Router.go 'fundTab',
                _id: fundId
                slug: 'settings'

              EZModal
                title: 'Setup Wizard'
                body: 'Blah blah blah'
      ]

Template.issue_finder.events
  'click .submit-github-url' : (e) ->
    url = $('#github-issue-url').val()
    # Example url: https://github.com/TAPevents/tap-i18n/issues/43
    # TODO: regex extracting for https://api.github.com/repos/:owner/:repo/issues/:number
    unless url.indexOf('https://github.com') is 0
      EZModal 'Invalid URL'
    else
      url = url.replace('https://github.com', 'https://api.github.com/repos')
      $.get(url).fail (err) ->
        EZModal 'Error fetching from github. Please check the URL.'
      .done (data) ->
        data.repository =
          full_name: url.split('/')[4..5].join('/')
        createFund data

Template.issue_finder_issue_cell.events
  'click .new-issue' : (e) ->
    e.preventDefault()
    createFund @

