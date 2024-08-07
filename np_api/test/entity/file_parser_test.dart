import 'package:np_api/src/entity/entity.dart';
import 'package:np_api/src/entity/file_parser.dart';
import 'package:test/test.dart';

void main() {
  group("FileParser", () {
    group("parse", () {
      test("file", _files);
      test("file w/ 404 properties", _files404props);
      test("file w/ metadata", _filesMetadata);
      test("file w/ is-archived", _filesIsArchived);
      test("file w/ override-date-time", _filesOverrideDateTime);
      test("multiple files", _filesMultiple);
      test("directory", _filesDir);
      test("nextcloud hosted in subdir", _filesServerHostedInSubdir);
    });
  });
}

Future<void> _files() async {
  const xml = """
<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:"
	xmlns:s="http://sabredav.org/ns"
	xmlns:oc="http://owncloud.org/ns"
	xmlns:nc="http://nextcloud.org/ns">
	<d:response>
		<d:href>/remote.php/dav/files/admin/Nextcloud%20intro.mp4</d:href>
		<d:propstat>
			<d:prop>
				<d:getlastmodified>Fri, 01 Jan 2021 02:03:04 GMT</d:getlastmodified>
				<d:getetag>&quot;1324f58d4d5c8d81bed6e4ed9d5ea862&quot;</d:getetag>
				<d:getcontenttype>video/mp4</d:getcontenttype>
				<d:resourcetype/>
        <oc:fileid>123</oc:fileid>
				<d:getcontentlength>3963036</d:getcontentlength>
				<nc:has-preview>false</nc:has-preview>
			</d:prop>
			<d:status>HTTP/1.1 200 OK</d:status>
		</d:propstat>
	</d:response>
</d:multistatus>
""";
  final results = await FileParser().parse(xml);
  expect(results, [
    File(
      href: "/remote.php/dav/files/admin/Nextcloud intro.mp4",
      contentLength: 3963036,
      contentType: "video/mp4",
      etag: "1324f58d4d5c8d81bed6e4ed9d5ea862",
      lastModified: DateTime.utc(2021, 1, 1, 2, 3, 4),
      hasPreview: false,
      fileId: 123,
      isCollection: false,
    ),
  ]);
}

Future<void> _files404props() async {
  const xml = """
<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:"
	xmlns:s="http://sabredav.org/ns"
	xmlns:oc="http://owncloud.org/ns"
	xmlns:nc="http://nextcloud.org/ns">
	<d:response>
		<d:href>/remote.php/dav/files/admin/Nextcloud%20intro.mp4</d:href>
		<d:propstat>
			<d:prop>
				<d:getlastmodified>Fri, 01 Jan 2021 02:03:04 GMT</d:getlastmodified>
				<d:getetag>&quot;1324f58d4d5c8d81bed6e4ed9d5ea862&quot;</d:getetag>
				<d:getcontenttype>video/mp4</d:getcontenttype>
				<d:resourcetype/>
        <oc:fileid>123</oc:fileid>
				<d:getcontentlength>3963036</d:getcontentlength>
				<nc:has-preview>false</nc:has-preview>
			</d:prop>
			<d:status>HTTP/1.1 200 OK</d:status>
		</d:propstat>
		<d:propstat>
			<d:prop>
				<d:quota-used-bytes/>
				<d:quota-available-bytes/>
			</d:prop>
			<d:status>HTTP/1.1 404 Not Found</d:status>
		</d:propstat>
	</d:response>
</d:multistatus>
""";
  final results = await FileParser().parse(xml);
  expect(results, [
    File(
      href: "/remote.php/dav/files/admin/Nextcloud intro.mp4",
      contentLength: 3963036,
      contentType: "video/mp4",
      etag: "1324f58d4d5c8d81bed6e4ed9d5ea862",
      lastModified: DateTime.utc(2021, 1, 1, 2, 3, 4),
      hasPreview: false,
      fileId: 123,
      isCollection: false,
    ),
  ]);
}

Future<void> _filesMetadata() async {
  const xml = """
<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:"
	xmlns:s="http://sabredav.org/ns"
	xmlns:oc="http://owncloud.org/ns"
	xmlns:nc="http://nextcloud.org/ns">
	<d:response>
		<d:href>/remote.php/dav/files/admin/Photos/Nextcloud%20community.jpg</d:href>
		<d:propstat>
			<d:prop>
				<d:getlastmodified>Fri, 01 Jan 2021 02:03:04 GMT</d:getlastmodified>
				<d:getetag>&quot;8950e39a034e369237d9285e2d815a50&quot;</d:getetag>
				<d:getcontenttype>image/jpeg</d:getcontenttype>
				<d:resourcetype/>
        <oc:fileid>123</oc:fileid>
				<d:getcontentlength>797325</d:getcontentlength>
				<nc:has-preview>true</nc:has-preview>
				<x1:metadata xmlns:x1="com.nkming.nc_photos">{&quot;version&quot;:2,&quot;lastUpdated&quot;:&quot;2021-01-02T03:04:05.678Z&quot;,&quot;fileEtag&quot;:&quot;8950e39a034e369237d9285e2d815a50&quot;,&quot;imageWidth&quot;:3000,&quot;imageHeight&quot;:2000}</x1:metadata>
			</d:prop>
			<d:status>HTTP/1.1 200 OK</d:status>
		</d:propstat>
	</d:response>
</d:multistatus>
""";
  final results = await FileParser().parse(xml);
  expect(results, [
    File(
      href: "/remote.php/dav/files/admin/Photos/Nextcloud community.jpg",
      contentLength: 797325,
      contentType: "image/jpeg",
      etag: "8950e39a034e369237d9285e2d815a50",
      lastModified: DateTime.utc(2021, 1, 1, 2, 3, 4),
      hasPreview: true,
      fileId: 123,
      isCollection: false,
      customProperties: {
        "com.nkming.nc_photos:metadata":
            "{\"version\":2,\"lastUpdated\":\"2021-01-02T03:04:05.678Z\",\"fileEtag\":\"8950e39a034e369237d9285e2d815a50\",\"imageWidth\":3000,\"imageHeight\":2000}",
      },
    ),
  ]);
}

Future<void> _filesIsArchived() async {
  const xml = """
<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:"
	xmlns:s="http://sabredav.org/ns"
	xmlns:oc="http://owncloud.org/ns"
	xmlns:nc="http://nextcloud.org/ns">
	<d:response>
		<d:href>/remote.php/dav/files/admin/Photos/Nextcloud%20community.jpg</d:href>
		<d:propstat>
			<d:prop>
				<d:getlastmodified>Fri, 01 Jan 2021 02:03:04 GMT</d:getlastmodified>
				<d:getetag>&quot;8950e39a034e369237d9285e2d815a50&quot;</d:getetag>
				<d:getcontenttype>image/jpeg</d:getcontenttype>
				<d:resourcetype/>
				<d:getcontentlength>797325</d:getcontentlength>
				<nc:has-preview>true</nc:has-preview>
				<x1:is-archived xmlns:x1="com.nkming.nc_photos">true</x1:is-archived>
			</d:prop>
			<d:status>HTTP/1.1 200 OK</d:status>
		</d:propstat>
	</d:response>
</d:multistatus>
""";
  final results = await FileParser().parse(xml);
  expect(results, [
    File(
      href: "/remote.php/dav/files/admin/Photos/Nextcloud community.jpg",
      contentLength: 797325,
      contentType: "image/jpeg",
      etag: "8950e39a034e369237d9285e2d815a50",
      lastModified: DateTime.utc(2021, 1, 1, 2, 3, 4),
      hasPreview: true,
      isCollection: false,
      customProperties: {
        "com.nkming.nc_photos:is-archived": "true",
      },
    ),
  ]);
}

Future<void> _filesOverrideDateTime() async {
  const xml = """
<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:"
	xmlns:s="http://sabredav.org/ns"
	xmlns:oc="http://owncloud.org/ns"
	xmlns:nc="http://nextcloud.org/ns">
	<d:response>
		<d:href>/remote.php/dav/files/admin/Photos/Nextcloud%20community.jpg</d:href>
		<d:propstat>
			<d:prop>
				<d:getlastmodified>Fri, 01 Jan 2021 02:03:04 GMT</d:getlastmodified>
				<d:getetag>&quot;8950e39a034e369237d9285e2d815a50&quot;</d:getetag>
				<d:getcontenttype>image/jpeg</d:getcontenttype>
				<d:resourcetype/>
				<d:getcontentlength>797325</d:getcontentlength>
				<nc:has-preview>true</nc:has-preview>
				<x1:override-date-time xmlns:x1="com.nkming.nc_photos">2021-01-02T03:04:05.000Z</x1:override-date-time>
			</d:prop>
			<d:status>HTTP/1.1 200 OK</d:status>
		</d:propstat>
	</d:response>
</d:multistatus>
""";
  final results = await FileParser().parse(xml);
  expect(results, [
    File(
      href: "/remote.php/dav/files/admin/Photos/Nextcloud community.jpg",
      contentLength: 797325,
      contentType: "image/jpeg",
      etag: "8950e39a034e369237d9285e2d815a50",
      lastModified: DateTime.utc(2021, 1, 1, 2, 3, 4),
      hasPreview: true,
      isCollection: false,
      customProperties: {
        "com.nkming.nc_photos:override-date-time": "2021-01-02T03:04:05.000Z",
      },
    ),
  ]);
}

Future<void> _filesMultiple() async {
  const xml = """
<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:"
	xmlns:s="http://sabredav.org/ns"
	xmlns:oc="http://owncloud.org/ns"
	xmlns:nc="http://nextcloud.org/ns">
	<d:response>
		<d:href>/remote.php/dav/files/admin/Nextcloud%20intro.mp4</d:href>
		<d:propstat>
			<d:prop>
				<d:getlastmodified>Fri, 01 Jan 2021 02:03:04 GMT</d:getlastmodified>
				<d:getetag>&quot;1324f58d4d5c8d81bed6e4ed9d5ea862&quot;</d:getetag>
				<d:getcontenttype>video/mp4</d:getcontenttype>
				<d:resourcetype/>
        <oc:fileid>123</oc:fileid>
				<d:getcontentlength>3963036</d:getcontentlength>
				<nc:has-preview>false</nc:has-preview>
			</d:prop>
			<d:status>HTTP/1.1 200 OK</d:status>
		</d:propstat>
	</d:response>
	<d:response>
		<d:href>/remote.php/dav/files/admin/Nextcloud.png</d:href>
		<d:propstat>
			<d:prop>
				<d:getlastmodified>Sat, 02 Jan 2021 03:04:05 GMT</d:getlastmodified>
				<d:getetag>&quot;48689d5b17c449d9db492ffe8f7ab8a6&quot;</d:getetag>
				<d:getcontenttype>image/png</d:getcontenttype>
				<d:resourcetype/>
        <oc:fileid>124</oc:fileid>
				<d:getcontentlength>50598</d:getcontentlength>
				<nc:has-preview>true</nc:has-preview>
				<x1:metadata xmlns:x1="com.nkming.nc_photos">{&quot;version&quot;:2,&quot;lastUpdated&quot;:&quot;2021-01-02T03:04:05.678000Z&quot;,&quot;fileEtag&quot;:&quot;48689d5b17c449d9db492ffe8f7ab8a6&quot;,&quot;imageWidth&quot;:500,&quot;imageHeight&quot;:500}</x1:metadata>
			</d:prop>
			<d:status>HTTP/1.1 200 OK</d:status>
		</d:propstat>
	</d:response>
</d:multistatus>
""";
  final results = await FileParser().parse(xml);
  expect(results, [
    File(
      href: "/remote.php/dav/files/admin/Nextcloud intro.mp4",
      contentLength: 3963036,
      contentType: "video/mp4",
      etag: "1324f58d4d5c8d81bed6e4ed9d5ea862",
      lastModified: DateTime.utc(2021, 1, 1, 2, 3, 4),
      hasPreview: false,
      fileId: 123,
      isCollection: false,
    ),
    File(
      href: "/remote.php/dav/files/admin/Nextcloud.png",
      contentLength: 50598,
      contentType: "image/png",
      etag: "48689d5b17c449d9db492ffe8f7ab8a6",
      lastModified: DateTime.utc(2021, 1, 2, 3, 4, 5),
      hasPreview: true,
      fileId: 124,
      isCollection: false,
      customProperties: {
        "com.nkming.nc_photos:metadata":
            "{\"version\":2,\"lastUpdated\":\"2021-01-02T03:04:05.678000Z\",\"fileEtag\":\"48689d5b17c449d9db492ffe8f7ab8a6\",\"imageWidth\":500,\"imageHeight\":500}",
      },
    ),
  ]);
}

Future<void> _filesDir() async {
  const xml = """
<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:"
	xmlns:s="http://sabredav.org/ns"
	xmlns:oc="http://owncloud.org/ns"
	xmlns:nc="http://nextcloud.org/ns">
	<d:response>
		<d:href>/remote.php/dav/files/admin/Photos/</d:href>
		<d:propstat>
			<d:prop>
				<d:getlastmodified>Fri, 01 Jan 2021 02:03:04 GMT</d:getlastmodified>
				<d:getetag>&quot;123456789abcd&quot;</d:getetag>
				<d:resourcetype>
					<d:collection/>
				</d:resourcetype>
        <oc:fileid>123</oc:fileid>
        <nc:has-preview>false</nc:has-preview>
			</d:prop>
			<d:status>HTTP/1.1 200 OK</d:status>
		</d:propstat>
		<d:propstat>
			<d:prop>
				<d:getcontenttype/>
				<d:getcontentlength/>
				<x1:metadata xmlns:x1="com.nkming.nc_photos"/>
			</d:prop>
			<d:status>HTTP/1.1 404 Not Found</d:status>
		</d:propstat>
	</d:response>
</d:multistatus>
""";
  final results = await FileParser().parse(xml);
  expect(results, [
    File(
      href: "/remote.php/dav/files/admin/Photos/",
      etag: "123456789abcd",
      lastModified: DateTime.utc(2021, 1, 1, 2, 3, 4),
      isCollection: true,
      hasPreview: false,
      fileId: 123,
    ),
  ]);
}

Future<void> _filesServerHostedInSubdir() async {
  const xml = """
<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:"
	xmlns:s="http://sabredav.org/ns"
	xmlns:oc="http://owncloud.org/ns"
	xmlns:nc="http://nextcloud.org/ns">
	<d:response>
		<d:href>/nextcloud/remote.php/dav/files/admin/Nextcloud%20intro.mp4</d:href>
		<d:propstat>
			<d:prop>
				<d:getlastmodified>Fri, 01 Jan 2021 02:03:04 GMT</d:getlastmodified>
				<d:getetag>&quot;1324f58d4d5c8d81bed6e4ed9d5ea862&quot;</d:getetag>
				<d:getcontenttype>video/mp4</d:getcontenttype>
				<d:resourcetype/>
        <oc:fileid>123</oc:fileid>
				<d:getcontentlength>3963036</d:getcontentlength>
				<nc:has-preview>false</nc:has-preview>
			</d:prop>
			<d:status>HTTP/1.1 200 OK</d:status>
		</d:propstat>
	</d:response>
</d:multistatus>
""";
  final results = await FileParser().parse(xml);
  expect(results, [
    File(
      href: "/nextcloud/remote.php/dav/files/admin/Nextcloud intro.mp4",
      contentLength: 3963036,
      contentType: "video/mp4",
      etag: "1324f58d4d5c8d81bed6e4ed9d5ea862",
      lastModified: DateTime.utc(2021, 1, 1, 2, 3, 4),
      hasPreview: false,
      fileId: 123,
      isCollection: false,
    ),
  ]);
}
