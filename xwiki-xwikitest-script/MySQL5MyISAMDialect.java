package org.hibernate.dialect;

public class MySQL5MyISAMDialect extends MySQL5Dialect {
    @Override
    public String getTableTypeString() {
        return " ENGINE=MyISAM";
    }

    @Override
    public boolean dropConstraints() {
        return false;
    }
}
