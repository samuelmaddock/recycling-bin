(function (exports) {

function BufferOverflowException() {
    this.message = "Read past the end of the buffer!";
    this.name = "BufferOverflowException";
}

function WriteTypeException() {
    this.message = "Unable to write type!";
    this.name = "WriteTypeException";
}

var BitBuff = function( str ) {
    if (str == undefined) str = "";
    this.buffer = [];
    this.position = 0;
    for(var i in str) {
        this.buffer.push( str.charCodeAt(i) );
    }
}

BitBuff.fromNodeBuffer = function( buffer, start, end ) {
    start = start || 0;
    end = end || buffer.length;

    var b = [];
    for (var i = start; i < end; i++) {
        b.push(buffer.readUInt8(i));
    }

    var buf = new BitBuff();
    buf.buffer = b;
    return buf;
}

BitBuff.prototype = new BitBuff();
BitBuff.prototype.constructor = BitBuff;

BitBuff.prototype.Length = function() {
    return this.buffer.length;
}

BitBuff.prototype.ReadByte = function() {
    if (this.position + 1 > this.buffer.length) {
        throw new BufferOverflowException();
    }
    return this.buffer[ this.position++ ];
}

BitBuff.prototype.WriteByte = function( b ) {
    this.buffer.push( b );
}

/*BitBuff.prototype.ReadChar = function() {
    return String.fromCharCode( this.ReadByte() );
}

BitBuff.prototype.WriteChar = function( c ) {
    return this.WriteByte( String.prototype.charCodeAt.call( c ) );
}*/

BitBuff.prototype.ReadString = function() {
    var len = this.ReadShort();
    var str = [];
    for(var i = 0; i < len; i++) {
        str.push(this.ReadByte());
    }
    return new Buffer(str).toString();
}

BitBuff.prototype.WriteString = function( str ) {
    var b = new Buffer(str, 'utf8');
    var len = b.length;

    this.WriteShort( len );

    for (var i = 0; i < len; i++) {
        this.WriteByte( b.readUInt8(i) );
    }
}

BitBuff.prototype.ReadShort = function() {
    return ( this.ReadByte() << 8 ) + this.ReadByte();
}

BitBuff.prototype.WriteShort = function( s ) {
    this.WriteByte( ( s >> 8 ) & 0xFF );
    this.WriteByte( s & 0xFF );
}

BitBuff.prototype.ReadInt = function() {
    return ( this.ReadByte() << 24 ) + ( this.ReadByte() << 16 ) + ( this.ReadByte() << 8 ) + this.ReadByte();
}

BitBuff.prototype.WriteInt = function( i ) {
    this.WriteByte( ( i >> 24 ) & 0xFF );
    this.WriteByte( ( i >> 16 ) & 0xFF );
    this.WriteByte( ( i >> 8 ) & 0xFF );
    this.WriteByte( i & 0xFF );
}

BitBuff.prototype.ReadLong = function() {
    return ( this.ReadByte() << 56 ) + ( this.ReadByte() << 48 ) + ( this.ReadByte() << 40 ) + ( this.ReadByte() << 32 ) +
        ( this.ReadByte() << 24 ) + ( this.ReadByte() << 16 ) + ( this.ReadByte() << 8 ) + this.ReadByte();
}

BitBuff.prototype.WriteLong = function( l ) {
    this.WriteByte( ( l >> 56 ) & 0xFF );
    this.WriteByte( ( l >> 48 ) & 0xFF );
    this.WriteByte( ( l >> 40 ) & 0xFF );
    this.WriteByte( ( l >> 32 ) & 0xFF );
    this.WriteByte( ( l >> 24 ) & 0xFF );
    this.WriteByte( ( l >> 16 ) & 0xFF );
    this.WriteByte( ( l >> 8 ) & 0xFF );
    this.WriteByte( l & 0xFF );
}

var TYPE_NIL = 0,
    TYPE_STRING = 4,
    TYPE_NUMBER = 3,
    TYPE_TABLE = 5,
    TYPE_BOOL = 1;

var TYPE_MAP = {
  'boolean': TYPE_BOOL,
  'number': TYPE_NUMBER,
  'string': TYPE_STRING,
  'object': TYPE_TABLE
};

// write JavaScript objects
BitBuff.prototype.WriteTable = function( obj ) {
  for (var prop in obj) {
    if (obj.hasOwnProperty(prop)) {
      var k = prop,
          v = obj[prop];

      if (TYPE_MAP[typeof v]) {
        this.WriteType( k );
        this.WriteType( v );
      }
    }
  }
  this.WriteByte( 0 );
}

BitBuff.prototype.WriteType = function ( obj ) {
  switch (TYPE_MAP[typeof obj]) {
    case TYPE_NIL:
      this.WriteByte( TYPE_NIL );
      break;
    case TYPE_STRING:
      this.WriteByte( TYPE_STRING );
      this.WriteString( obj );
      break;
    case TYPE_NUMBER:
      this.WriteByte( TYPE_NUMBER );
      this.WriteNumber( obj );
      break;
    case TYPE_TABLE:
      this.WriteByte( TYPE_TABLE );
      this.WriteTable( obj );
      break;
    case TYPE_BOOL:
      this.WriteByte( TYPE_BOOL );
      this.WriteByte( obj ? 1 : 0 );
      break;
    default:
      throw new WriteTypeException();
  }
}

BitBuff.prototype.Remaining = function() {
    var i = this.position,
        j = this.buffer.length - 1;

    var b = [];
    while (i <= j) {
        b.push( this.ReadByte() );
        i++;
    }

    return new Buffer(b).toString();
}

BitBuff.prototype.ToString = function() {
    return new Buffer(this.buffer).toString();
}

BitBuff.prototype.ToNodeBuffer = function() {
    return new Buffer(this.buffer);
}

BitBuff.prototype.Seek = function( pos ) {
    this.position = pos;
}

BitBuff.prototype.Tell = function() {
    return this.position;
}

if (typeof module !== 'undefined' && exports === module.exports) {
    module.exports = BitBuff;
} else {
    exports.BitBuff = BitBuff;
}

})(this);
