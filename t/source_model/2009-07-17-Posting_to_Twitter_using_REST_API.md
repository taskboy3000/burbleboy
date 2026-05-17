title: Posting to Twitter using REST API
time: 2009-07-17T00:00:00Z
published_filename: 2009-07-17-Posting_to_Twitter_using_REST_API.html
guid: 4EB20000-A64B-11E8-A8F5-607881BCFB3A
tags: HTTP,LWP::UserAgent,perl,programming,rest,soap,twitter,web services,xml-rpc

<div align="center">
<img src="/img/camel.gif" class="insert" alt="Perl as internet duct tape">
</div>
<br />

<p>For a long time, I've ignore the 
<a href="http://en.wikipedia.org/wiki/Representational_State_Transfer">Representational State Transfer</a> (REST) 
architecture.  For one thing, I don't particularly agree with its premise 
that remote procedure calls (RPC) that use HTTP as a transport mechanism 
should obey the same semantics as regular web traffic.  Things like 
XML-RPC and SOAP are, to my thinking, happening on an entirely different layer 
of the application stack than HTTP.  Indeed, there are implementations of 
XML-RPC that do no use HTTP at all.</p>

<p>I remember pretty heated arguments I witnessed at tech conferences in the 
early 2000s about this seemingly unimportant technical point.  For REST 
adherents, web services are another form of web traffic and should be treated 
as such.  Given that Twitter, Facebook and Bit.ly all use REST for their APIs
and older apps like liveJournal use XML-RPC/SOAP, I guess REST is the new 
hotness.</p>

<p>I've recently had reason to interact with the Twitter and Bit.ly APIs.  
This has made me come to terms with REST RPC mechnanisms.  I admit, the sad, 
sick part of me that enjoys playing around with low-level HTTP stuff finds 
satisfaction in the way these API leverage existing HTTP features like basic 
authentication, extra path info, and GET and POST semantics.  In this post, 
I thought I would show a bit of Perl code I wrote post status updates to 
Twitter, an activity more commonly referred to as "tweeting."</p>

<p><a href="http://apiwiki.twitter.com/">Twitter's API documentation</a> is 
relatively straight forward, if you already have a solid grounding in HTTP.
The API call to tweet is called <a href="http://apiwiki.twitter.com/Twitter-REST-API-Method%3A-statuses%C2%A0update">"statuses/update"</a>.  The basics of the 
RPC mechanism are easy enough:</p>

<ul>
  <li>The caller makes a HTTP GET or POST request
  <li>The sender replies with content in the form of JSON or  XML
</ul>

<p>Let's start with the request.  There are serveral bits of information
required by the API: user credentials, the URL and additional query parameters.
The user credentials are passed as part of the HTTP request header as a basic
authentication field, which is merely a base64 string that is the concatenation 
of the username and password of your Twitter account.  Fortunately, Perl's 
HTTP::Request::Common class makes it easy to add basic auth credentials 
to the request
without knowing how this information is encoded in the HTTP request.</p>
  
<p>The next bit is the URL to the function.  This is a core idea of REST -- 
function calls should have URIs and look like ordinary web resources.  
In this case, the URL is <code>http://twitter.com/statuses/update.xml</code>.
Interestingly, the response from twitter can be encoded in a number of formats.
These formats are determined by the extension you give to the URL.  For 
instance, I could have request the metainformation about myself in 
<a href="http://en.wikipedia.org/wiki/Json">JSON</a> with the following URL: 
<code>http://twitter.com/users/show/taskboy3000.json</code>.</p>

<p>The text of the tweet must be passed to the URL as if it were POSTed from a 
form.  The parameter name is <code>status</code>.  The status must be encoded
as if the data were submitted from an HTML form.  Again, Perl makes this very 
easy, as will be shown below.</p>

<pre class="code">
use LWP::UserAgent;
use HTTP::Request::Common ('POST')

my $api_url = q[http://twitter.com/statuses/update.xml];
my $status = "Tweeting from the API!";
my $twitter_username = "taskboy3000";
my $twitter_password = "s3cr3t";

my $ua = LWP::UserAgent->new;
my $req = POST($api_url => [status => $status]);
$req->authorization_basic($twitter_username 
			  => $twitter_password);

# Make the request
my $res = $ua->request($req);
</pre>

<p>The code above is sets up and makes the status RPC call to twitter.
The first thing needed is an LWP::UserAgent object, which is kind of like 
a web browser.  It makes HTTP requests of web servers.  To construct the 
POST request, I use HTTP::Request::Common::POST.  Because I can pass in 
form parameters as plain perl data structures, it frees me from worrying 
about urlencoding values and fooling around with HTTP headers that 
are germain to the task at hand.  POST() returns an HTTP::Request object.</p>

<p>Adding my twitter account credentials to the request is a simple one line 
call to authorization_basic().  Very handy and very clean.  That's all 
the setup I need to make the request.  I pass in the HTTP::Request object
to the User Agent object.  That makes the actual network connection to the 
URL.  The response comes back in the form of an HTTP::Response object, which 
I'll discuss next.</p>

<p>If all has gone well with the request, I'll get back an XML document that 
looks something like this:</p>

<pre class="code">
&lt;?xml version="1.0" encoding="UTF-8"?>
&lt;status>
&lt;created_at>Tue Apr 07 22:52:51 +0000 2009&lt;/created_at>
&lt;id>1472669360&lt;/id>
&lt;text>At least I can get your humor through tweets. 
RT @abdur: I don't mean this in a bad way, but 
genetically speaking your a cul-de-sac.&lt;/text>
&lt;truncated>false&lt;/truncated>
&lt;in_reply_to_status_id>1472669230&lt;/in_reply_to_status_id>
&lt;in_reply_to_user_id>10759032&lt;/in_reply_to_user_id>
&lt;favorited>false&lt;/favorited>
&lt;in_reply_to_screen_name>&lt;/in_reply_to_screen_name>
&lt;user>
&lt;id>1401881&lt;/id>
 &lt;name>Doug Williams&lt;/name>
 &lt;screen_name>dougw&lt;/screen_name>
 &lt;location>San Francisco, CA&lt;/location>
 &lt;description>Twitter API Support. Internet, greed, 
users, dougw and opportunities are 
my passions.&lt;/description>
 &lt;url>http://www.igudo.com&lt;/url>
 &lt;protected>false&lt;/protected>
 &lt;followers_count>1027&lt;/followers_count>
 &lt;profile_text_color>000000&lt;/profile_text_color>
 &lt;profile_link_color>0000ff&lt;/profile_link_color>
 &lt;friends_count>293&lt;/friends_count>
 &lt;created_at>Sun Mar 18 06:42:26 +0000 2007&lt;/created_at>
 &lt;favourites_count>0&lt;/favourites_count>
 &lt;utc_offset>-18000&lt;/utc_offset>
 &lt;time_zone>Eastern Time (US & Canada)&lt;/time_zone>
 &lt;profile_background_tile>false&lt;/profile_background_tile>
 &lt;statuses_count>3390&lt;/statuses_count>
 &lt;notifications>false&lt;/notifications>
 &lt;following>false&lt;/following>
 &lt;verified>true&lt;/verified>
&lt;/user>
&lt;/status>
</pre>

<p>Most of this, I don't care about.  However, I do want to see if there's an 
<error> tag.  If so, there was a problem with the post.  The way I handle 
this error checking can be see in the following code.</p>

<pre class="code"> 
unless ($res->is_success) {
    my $c = $res->content;
    my ($errstr) = ($c =~ m!&lt;error>([^&lt;]+)&lt;/error>!);
    warn(sprintf("Post failed (%d): $errstr\n", $res->code));
    exit 1;
}

print "OK\n";
exit 0; 
</pre>

<p>Without the services of a full XML parser, it's relatively easy to look 
for an error tag and extract the contents for display.  The error message I've 
encountered most is essentially "you used the API too much".  Twitter does 
restrict the usage of some of their API calls, but not the status one.</p>

<p>If you collapse all the Perl code, you're looking at less than 20 lines of 
code.  If you wanted to, you could even make posts using the very handy 
command line tool curl:
<code>curl -u taskboy:s3cr3t -d "status=hello curl" \<br/>
http://twitter.com/statuses/update.xml</code></p>

<p>I will leave the checking of error messages from curl output as an 
excerise for the reader.</p>

<p>As I said, REST RPC mechanisms are fun and interesting if you already 
understand HTTP.  However, not everyone does.  I think XML-RPC and SOAP 
libraries to a better job of insulating the programmer from the HTTP 
protocol, allowing him to focus on the API task at hand.</p> 

