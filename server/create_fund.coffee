cleanUrls = (obj) ->
  for key, val of obj
    if key.indexOf('_url') > -1 and key isnt 'html_url'
      delete obj[key]
    else if val is Object(val)
      val = cleanUrls(val)
  return obj

cleanFund = (rawIssue) ->
  fund = _.pick cleanUrls(rawIssue), "body", "title"

  fund.body = """
  ## Original Issue:
  #{fund.body}
  """

  fund.amountRaised = 0
  fund.targetAmount = 500

  return fund

Meteor.methods
  createFund : (options) ->
    unless options.issue_number and options.repo_name
      throw new Meteor.Error 'Invalid params'

    user = Meteor.users.findOne Meteor.userId()
    githubToken = user.services?.github?.accessToken

    unless githubToken
      throw new Meteor.Error 'You must be logged in using github to create a fund'

    # TODO make the following run in parallel for speed
    syncGithubCall = (url, ignoreError) ->
      do Meteor.wrapAsync (callback) ->
        Meteor.http.get url,
          headers : {"User-Agent" : "Meteor/1.0"}
          params: {access_token: githubToken} # use user's token to prevent rate limiting
        , (err, res) ->
          if err and !ignoreError
            throw new Meteor.Error err
          else
            callback null, res

    isCollaborator = syncGithubCall "https://api.github.com/repos/#{options.repo_name}/collaborators/#{user.services?.github?.username}", true
    repoRes = syncGithubCall "https://api.github.com/repos/#{options.repo_name}" # get public repo details
    issueRes = syncGithubCall "https://api.github.com/repos/#{options.repo_name}/issues/#{options.issue_number}" # get public issue details

    # TODO integrate into simple schema or collection2
    fund =
      published: false
      creatorId: user._id
      creatorIsCollaborator: isCollaborator.headers.status is "204 No Content"
      issue: cleanUrls issueRes.data
      fund: cleanFund issueRes.data
      repo: cleanUrls repoRes.data
      createdAt: new Date()

    if fund.repo.private isnt false
      throw new Meteor.Error 'Only public repos are supported right now'

    unless fund.issue.state is 'open'
      throw new Meteor.Error 'Issue must be open'

    if App.cols.Funds.findOne {'issue.id' : fund.issue.id, 'creatorId': user._id}
      throw new Meteor.Error 'You have already created a fund on this issue'

    return App.cols.Funds.insert fund
