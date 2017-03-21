import rados

try:
    cluster = rados.Rados(conffile='')
except TypeError as e:
    print 'Argument validation error: ', e
    raise e

print "Created cluster handle."

try:
    cluster.connect()
    if not cluster.pool_exists('data'):
        raise RuntimeError('No data pool exists')
    ioctx = cluster.open_ioctx('data')
    ioctx.write("py-hw", "Hello World!")
    ioctx.set_xattr("py-hw", "lang", "en_US")
    ioctx.write("py-object", "This is my object.")

    print ioctx.read("py-hw")
    print ioctx.get_xattr("py-hw", "lang")
    print ioctx.read("py-object")

    # ioctx.remove_object("py-hw")
    # ioctx.remove_object("py-object")

    ioctx.close()
    cluster.shutdown()
except Exception as e:
    print "connection error: ", e
    raise e
finally:
    print "Connected to the cluster."
